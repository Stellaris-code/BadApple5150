#include <iostream>
#include <fstream>
#include <vector>
#include <cstdint>
#include <cstring>
#include <map>
#include <deque>
#include <algorithm>
#include <assert.h>

using namespace std; 

int dummy;


std::map<int, int> cmd_freq;
std::map<std::pair<int, int>, int> pair_freq;

uint8_t codemap[256];
int reg_val[256];

#define THRESHOLD 1
#define DELAY 23
#define DELAY_SUBSTRACT 0

struct Pair
{
    uint8_t cmd;
    uint8_t val;
};

struct Packet
{
    std::vector<Pair> pairs;
    uint16_t delay;
    int dummy;
};

std::vector<Packet> basic_blocks;

void filter_block(Packet& block)
{
    Packet filtered;
    filtered.delay = block.delay;
    filtered.dummy = block.dummy;
    uint8_t cmds[256];
    memset(cmds, 0, 256);

    std::deque<Pair> temp;
    for (int i = block.pairs.size() - 1; i >= 0; --i)
    //for (int i = 0; i < block.pairs.size(); ++i)
    {
        auto pair = block.pairs[i];

        if ((codemap[pair.cmd&0x7F]) == 0xBD)
        {
            temp.push_front(pair);
        }
        else if ((codemap[pair.cmd&0x7F]&0xF0) == 0xB0 && pair.val == 0)
        {
            if (i < block.pairs.size())
            {
                auto next = block.pairs[i + 1];
                if (next.cmd == pair.cmd && (next.val&0x20) && false)
                    dummy = 1;
                else
                {
                    temp.push_front(pair);
                    //filtered.pairs.push_back(pair);
                    cmds[pair.cmd] = 1;
                }
            }
            else
            {
                temp.push_front(pair);
                //filtered.pairs.push_back(pair);
                cmds[pair.cmd] = 1;
            }
        }
        // consider only frequency changing codes
        else if (
                (((codemap[pair.cmd&0x7F]&0xF0) != 0xA0) &&
                 ((codemap[pair.cmd&0x7F]&0xF0) != 0x50) &&
                 ((codemap[pair.cmd&0x7F]&0xF0) != 0x40) &&
                 ((codemap[pair.cmd&0x7F]&0xF0) != 0xB0))
                || cmds[pair.cmd] == 0)
        {
            temp.push_front(pair);
            //filtered.pairs.push_back(pair);
            cmds[pair.cmd] = 1;
        }
    }

    for (auto val : temp)
    {
        filtered.pairs.push_back(val);
    }

    block = filtered;
}

void filter_similar(std::vector<Packet>& data)
{
    memset(reg_val, 0xdeadbeef, 256*sizeof(int));

    for (auto& packet : data)
    {
        Packet vec;
        vec.delay = packet.delay;
        vec.dummy = packet.dummy;
        for (auto& pair : packet.pairs)
        {
             uint8_t cmd = pair.cmd;
             uint8_t reg = codemap[pair.cmd & 0x7F];
             uint8_t val = pair.val;

            if ((reg&0xF0) == 0xA0 || (reg&0xF0) == 0x40)
            {
                if (std::abs((int)val - reg_val[cmd]) > THRESHOLD)
                {
                    vec.pairs.push_back(pair);
                    reg_val[cmd] = val;
                }
            }
            else
            {
                //if (val != reg_val[cmd])
                {
                    vec.pairs.push_back(pair);
                    reg_val[cmd] = val;
                }
            }
        }

        packet = vec;
    }
}

void parse(const uint8_t* ptr, const uint8_t* end)
{
    assert(memcmp(ptr, "DBRAWOPL", 8) == 0);
    ptr += 8;

    assert(*ptr == 2);
    ptr += 4; // version major, version minor (UINT16LE)

    uint32_t len_pairs, len_ms;
    len_pairs = *(uint32_t*)ptr; ptr += 4;
    len_ms = *(uint32_t*)ptr; ptr += 4;

    uint8_t hw_type = *ptr; ++ptr;
    uint8_t format = *ptr; ++ptr;
    assert(*ptr == 0); ++ptr; // no compression

    uint8_t short_delay = *ptr; ++ptr;
    uint8_t long_delay = *ptr; ++ptr;

    uint8_t codemap_len = *ptr; ++ptr;

    memcpy(codemap, ptr, codemap_len);
    ptr += codemap_len;

    dummy = 1;

    Packet basic_block;

    basic_block.delay = 0;
    basic_block.dummy = 0;

    uint8_t prev_reg = 0;
    for (int i = 0; i < len_pairs; ++i)
    {
        uint8_t cmd = *ptr; ++ptr;
        uint8_t val = *ptr; ++ptr;

        if (cmd == short_delay || cmd == long_delay)
        {
            uint16_t delay = val+1;
            if (cmd == long_delay)
               delay <<= 8;
            basic_block.delay += delay;

            if (basic_block.delay >= DELAY)
            {
                //basic_block.delay /= 2;
                if (basic_block.delay >= 256)
                {
                    basic_block.delay -= 256;
                    basic_block.dummy = 1; // means it's a long delay
                }
                else
                    basic_block.delay -= 1; // 0 based
                basic_blocks.push_back(basic_block);
                basic_block.pairs.clear();
                basic_block.delay = 0;
                basic_block.dummy = 0;
                continue;
            }
        }
        else
        {
            uint8_t reg = codemap[cmd & 0x7F];
            cmd_freq[cmd]++;

            if ((reg&0xF0) == 0xA0 || (reg&0xF0) == 0x40)
            {
                if (std::abs((int)val - reg_val[cmd]) > THRESHOLD)
                {
                    assert(val != reg_val[cmd]);
                    basic_block.pairs.push_back(Pair{cmd, val});
                    reg_val[cmd] = val;
                }
            }
            else if (reg_val[cmd] != val)
            {
                if (reg == 0xB2 && val == 0x21)
                {
                    printf("0x%x\n", reg_val[cmd]);
                    dummy = 2;
                }

                basic_block.pairs.push_back(Pair{cmd, val});
                reg_val[cmd] = val;
            }

            pair_freq[std::pair<int, int>(prev_reg, reg)]++;

            prev_reg = reg;
        }
    }

    basic_blocks.push_back(basic_block);
}

int main()
{
    std::fstream file("data_master_spedup.dro");

    std::vector<uint8_t> data;

    uint16_t ms_total = 0;

    if (!file.eof() && !file.fail())
    {
        file.seekg(0, std::ios_base::end);
        std::streampos fileSize = file.tellg();
        data.resize(fileSize);

        file.seekg(0, std::ios_base::beg);
        file.read((char*)data.data(), fileSize);
    }

    parse(data.data(), data.data() + data.size());

    {
        std::vector<std::pair<uint32_t, int>> pairs;
        for (auto itr = cmd_freq.begin(); itr != cmd_freq.end(); ++itr)
        {
            pairs.push_back(*itr);
        }

        std::sort(pairs.begin(), pairs.end(), [=](std::pair<uint32_t, int>& a, std::pair<uint32_t, int>& b)
        {
            return a.second > b.second;
        });

        for (int i = 0; i < 40 && i < pairs.size(); ++i)
        {
            printf("0x%X (0x%X) : %d\n", pairs[i].first, codemap[pairs[i].first&0x7F], pairs[i].second);
        }

        printf("-----\n");
    }

    {
        std::vector<std::pair<std::pair<int, int>, int>> pairs;
        for (auto itr = pair_freq.begin(); itr != pair_freq.end(); ++itr)
        {
            pairs.push_back(*itr);
        }

        std::sort(pairs.begin(), pairs.end(), [=](std::pair<std::pair<int, int>, int>& a, std::pair<std::pair<int, int>, int>& b)
        {
            return a.second > b.second;
        });

        for (int i = 0; i < 40 && i < pairs.size(); ++i)
        {
            printf("<0x%X, 0x%X> : %d\n", pairs[i].first.first, pairs[i].first.second, pairs[i].second);
        }

        printf("-----\n");
    }

    for (auto& block : basic_blocks)
        filter_block(block);

    filter_similar(basic_blocks);

    int estimated_size = 0;
    for (const auto& block : basic_blocks)
    {
        estimated_size += block.pairs.size()*2;
        estimated_size += 1; // could trim a delay byte
    }

    //estimated_size -= 11782/2;

    printf("estimated size : %f\n", estimated_size/1000.f);

    std::vector<uint8_t> output;
    for (int i = 0; i <= 0x93; ++i)
    {
        output.push_back(data[i]);
    }

    int pairs = 0;

    for (const auto& block : basic_blocks)
    {
        for (auto pair : block.pairs)
        {
            output.push_back(pair.cmd);
            output.push_back(pair.val);

            ++pairs;
        }

        if (block.dummy == 1)
        {
            // only handle this case yet
            // output short delays instead
            int del = block.delay;
            do
            {
                output.push_back(0x7A);
                output.push_back(128);
                output.push_back(0x7A);
                output.push_back(128);
                del -= 256;

                pairs += 2;
            } while (del >= 256);
            if (del > 0)
            {
                assert(del < 256);
                output.push_back(0x7A);
                output.push_back(del-1);
                ++pairs;
            }
            //output.push_back(0x7B);
            //output.push_back(block.delay >> 8);

            ms_total += block.delay + 256;
        }
        else
        {
            output.push_back(0x7A);
            output.push_back(block.delay - DELAY_SUBSTRACT);
            ++pairs;

            ms_total += block.delay+1;
        }

    }

#if 1

    // insert the segment switching command
    output.insert(output.begin()+0xFC00-2, 0x00); // segment switch
    output.insert(output.begin()+0xFC00-2, 0xFF);
    ++pairs;

    // insert the header table again (in order to reuse the codemap in the next segment)
    output.insert(output.begin()+0xFC00, data.begin(), data.begin()+0x94);

    output.push_back(0xFF);
    output.push_back(0x01); // end of data
    ++pairs;

#endif

    *(uint32_t*)&output[0xC] = pairs;

    printf("commands : %d\n", cmd_freq.size());
    printf("ms : %d\n", ms_total);

    for (int i = 0; i < 256; ++i)
    {
        if (cmd_freq.count(i) == 0)
        {
            printf("Command 0x%x available\n", i);
        }
    }

    std::ofstream FILE("out.dro", std::ios::out | std::ofstream::binary);
    std::copy(output.begin(), output.end(), std::ostreambuf_iterator<char>(FILE));
    return 0;
}
