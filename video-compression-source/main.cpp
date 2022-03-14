#include <iostream>
#include <QImage>
#include <QDebug>
#include <QFileInfo>
#include <vector>
#include <cstdint>
#include <set>
#include <fstream>

#define CYLINDER_SIZE (2*9*512)
#define FIRST_DISK_CYLINDERS 76

struct Lyric
{
    std::string text;
    int frame;
};

#define OFF1 12

Lyric lyrics[] =
{
    {" ", 0}, // sentinel
    {"Nagarete ku toki no naka de demo", 438},
    {"Kedarusa ga hora guruguru mawate", 490},
    {"Watashi kara hanareru kokoro mo", 544},
    {"Mienai wa so shiranai", 594},
    {"Jibun kara ugoku koto mo naku", 646},
    {"Toki no suki", 701},
    {"Ma ni nagasare tsuzukete", 716},
    {"Shiranai wa mawari no koto nado", 753},
    {"Watashi wa watashi sore dake", 802},
    {"Yume miteru? Nani mo mitenai?", 855},
    {"Kataru mo mudana jibun no kotoba", 899},
    {"Kanashimu nante tsukareru dakeyo", 954},
    {"Nani mo kanjizu sugoseba ii no", 1006},
    {"Tomadou kotoba atae rarete mo", 1058},
    {"Jibun no kokoro tada uwanosora", 1113},
    {"Moshi watashi kara", 1162},
    {"Ugoku no naraba", 1186},
    {"Subete kaeru no nara kuroni suru", 1215},
    {"Konna jibun ni mirai wa aru no?", 1267},
    {"Konna sekai ni watashi wa iruno?", 1321},
    {"Ima setsunai no? Ima kanashi no?", 1369},
    {"Jibun no koto mo wakaranai mama", 1422},
    {"Ayumu koto sae tsukareru dake yo", 1475},
    {"Hito no koto nado", 1533},
    {"Shiri mo shinai wa", 1551},
    {"Konna watashi mo kawareru nonara", 1580},
    {"Moshi kawareru no", 1634},
    {"Nara shiro ni naru", 1657},
    {" ", 1687},
    {"Nagare teku toki no naka de demo", 1899+OFF1},
    {"Kedarusa ga hora guruguru mawate", 1950+OFF1},
    {"Watashi kara hanareru kokoro mo", 2002+OFF1},
    {"Mienai wa so shiranai", 2055+OFF1},
    {"Jibun kara ugoku koto mo naku", 2108+OFF1},
    {"Toki no suki", 2158+OFF1},
    {"Ma ni nagasa re tsudzukete", 2179+OFF1},
    {"Shiranai wa mawari no koto nado", 2211+OFF1},
    {"Watashi wa watashi soredake", 2266+OFF1},
    {"Ima yume miteru? Nanimo mitenai?", 2315+OFF1},
    {"Kataru mo mudana jibun no kotoba", 2364+OFF1},
    {"Kanashimu nante tsukareru dakeyo", 2414+OFF1},
    {"Nani mo kanjizu sugoseba ii no", 2464+OFF1},
    {"Tomadou kotoba atae rarete mo", 2519+OFF1},
    {"Jibun no kokoro tada uwanosora", 2572+OFF1},
    {"Moshi watashi kara", 2626+OFF1},
    {"Ugoku no naraba", 2649+OFF1},
    {"Subete kaeru no nara kuroni suru", 2674+OFF1},
    {"Ugoku no naraba, Ugoku no naraba", 2730+OFF1},
    {"Subete kowasuwa, Subete kowasuwa", 2782+OFF1},
    {"Kanashimu naraba", 2831+OFF1},
    {"Kanashimu naraba", 2858+OFF1},
    {"Watashi no kokoro", 2887+OFF1},
    {"Shiroku kawareru?", 2910+OFF1},
    {"Anata no koto mo", 2938+OFF1},
    {"Watashi no koto mo", 2964+OFF1},
    {"Subete no koto mo", 2987+OFF1},
    {"Mada shiranai no", 3015+OFF1},
    {"Omoi mabuta o aketa nonaraba", 3040+OFF1},
    {"Subete kowasu no", 3093+OFF1},
    {"Nara kuro ni nare!!!", 3116+OFF1},
    {" ", 3143+OFF1},
    {" ", 9999} // sentinel
};
int next_lyric_idx = 1;

using namespace std;

int width;
int height;
int dummy;
QByteArray audio_data;

std::vector<uint8_t> rle_data(const std::vector<uint32_t>& img);

const int factor = 16;
std::vector<uint32_t> compress8bit(const std::vector<uint8_t>& in)
{

    std::vector<uint32_t> result;
    result.resize(in.size()/factor, 0);
    for (int i = 0; i < in.size()/factor; ++i)
    {
        for (int j = 0; j < factor; ++j)
        {
            result[i] <<= 1;
            result[i] |= in[i*factor + j];
        }
    }

    return result;
}


inline uint8_t get_pixel(const QImage& img, int x, int y)
{
    return img.constBits()[(y*img.width() + x)*4] >= 128 ? 1 : 0;
    //return img.pixel(x, y) == qRgb(255, 255, 255) ? 1 : 0;
}

std::vector<uint8_t> flatten(const QImage& img)
{
    std::vector<uint8_t> result;
    result.resize(img.width()*img.height(), 0);
    for (int i = 0; i < img.height(); ++i)
        for (int j = 0; j < img.width(); ++j)
            result[i*img.width() + j] = get_pixel(img, j, i);

    return result;
}

std::vector<uint32_t> compress_transpose(const QImage& img)
{
    std::vector<uint32_t> result;
    result.resize(img.width()*img.height()/factor, 0);
    for (int i = 0; i < img.height(); ++i)
        for (int j = 0; j < img.width()/factor; ++j)
        {
            for (int z = 0; z < factor; ++z)
            {
                result[j*img.height() + i] <<= 1;
                result[j*img.height() + i] |= get_pixel(img, j*factor + z, i);
            }
        }

    return result;
}

int frame_id;
int rle_passes = 0;
long long spare_counter = 0;
std::map<int, int> common_rle;
std::map<int, int> common_rle_val;
std::map<std::pair<int, int>, int> length_sequences;
std::map<uint32_t, int> commands;
// returns the amount of bytes necessary to hold the information
// Huffmann:

struct RlePacket
{
    enum Command : uint8_t
    {
        Repeat = 0,
        RepeatLine = 1,
        ShiftedSequence = 2,
        RepeatShifted = 3,
        XorSequence = 4,
        RepeatXor = 5,
        RawBlock16 = 6,
        EndOfLine = 7,
        EndOfFrame = 8,
        EndOfData = 9,

        RleCommandEnd
    } cmd;

    uint16_t len;
    uint16_t val;
    std::vector<uint32_t> sequence;
    bool mirrored;
};

std::vector<RlePacket> rle_packets(const std::vector<uint32_t>& img)
{
   std::vector<RlePacket> packets;

    uint32_t curval = img[0];
    int run_length = 1;
    int start = 0;

    // one additional iteration to collect the final command
    // Strive for a command_byte data_byte/word structure
    for (int i = 1; i < img.size()+1; ++i)
    {
        if ((i%height != 0) && i < img.size() && img[i] == img[i-1])
            ++run_length;
        else
        {
            assert(start/height == (start + run_length-1)/height); // make sure we're on the same column

            packets.push_back(RlePacket{RlePacket::Repeat, (uint16_t)run_length, (uint16_t)curval});

            // end of line bit
            if (i % height == 0 && run_length != height) // end of line is implicit for full height columns
            {
                packets.push_back(RlePacket{RlePacket::EndOfLine, 0, 0});
            }

            curval = img[i];
            run_length = 1;
            start = i;
        }
    }
    assert(run_length == 1);

    packets.push_back(RlePacket{RlePacket::EndOfFrame, 0, 0});

    return packets;
}

std::vector<RlePacket> optimize_shifted_sequences(const std::vector<RlePacket>& data, bool mirrored)
{
    std::vector<RlePacket> result;

    std::vector<uint32_t> sequence;

    int total_counter = 0;
    int counter = 0;
    uint16_t curval = 0;
    for (size_t i = 0; i < data.size(); ++i)
    {
        curval = data[i].val;

        bool shifted_sequence = false;
        int p;
        for (p = 0; p < factor; ++p)
        {
            uint16_t val = 0xFFFF >> p;
            if ((!mirrored && curval == val) ||
                (mirrored && curval == (~val&0xFFFF)))
            {
                shifted_sequence = true;
                break;
            }
        }

        if (data[i].len == 1 && data[i].cmd == RlePacket::Repeat && shifted_sequence)
        {
            sequence.push_back(p);
            ++counter;
        }
        else
        {
            if (counter > 0)
            {
                assert(counter == sequence.size());
                result.push_back(RlePacket{RlePacket::ShiftedSequence, (uint16_t)counter, 0, sequence, mirrored});
            }

            sequence.clear();
            result.push_back(data[i]);
            total_counter += counter;
            counter = 0;
        }
    }
    assert(counter == 0);

    return result;
}

std::vector<RlePacket> optimize_shifted_repeat(const std::vector<RlePacket>& data, bool mirrored)
{
    std::vector<RlePacket> result;

    uint16_t curval = 0;
    for (size_t i = 0; i < data.size(); ++i)
    {
        curval = data[i].val;

        bool shifted_sequence = false;
        int p;
        for (p = 0; p < factor; ++p)
        {
            uint16_t val = 0xFFFF >> p;
            if ((!mirrored && curval == val) ||
                (mirrored && curval == (~val&0xFFFF)))
            {
                shifted_sequence = true;
                break;
            }
        }

        if (data[i].cmd == RlePacket::Repeat && shifted_sequence)
        {
            result.push_back(RlePacket{RlePacket::RepeatShifted, data[i].len, (uint16_t)p, {}, mirrored});
        }
        else
        {
            result.push_back(data[i]);
        }
    }

    return result;
}

std::vector<RlePacket> optimize_xor_repeat(const std::vector<RlePacket>& data)
{
    uint16_t lut[16] = {0x2, 0x4000, 0x4, 0x2000, 0x8, 0x10, 0x800, 0x1000,
                        0x20, 0x400, 0x100, 0x200, 0x40, 0x80, 0x8000, 0x1};

    std::vector<RlePacket> result;

    result.push_back(data[0]);
    for (size_t i = 1; i < data.size(); ++i)
    {
        uint16_t _xor = data[i-1].val ^ data[i].val;
        uint16_t* it;

        if (data[i-1].cmd == RlePacket::Repeat && data[i].cmd == RlePacket::Repeat &&
                (it = std::find(std::begin(lut), std::end(lut), _xor)) != std::end(lut))
        {
            result.push_back(RlePacket{RlePacket::RepeatXor, data[i].len, (uint16_t)(it - lut)});
        }
        else
        {
            result.push_back(data[i]);
        }
    }

    return result;
}

std::vector<RlePacket> optimize_xor_sequences(const std::vector<RlePacket>& data)
{
    uint16_t lut[16] = {0x2, 0x4000, 0x4, 0x2000, 0x8, 0x10, 0x800, 0x1000,
                        0x20, 0x400, 0x100, 0x200, 0x40, 0x80, 0x8000, 0x1};

    std::vector<RlePacket> result;
    std::vector<uint32_t> sequence;

    int counter = 0;
    result.push_back(data[0]);
    for (size_t i = 1; i < data.size(); ++i)
    {
        uint16_t _xor = data[i-1].val ^ data[i].val;
        uint16_t* it;

        if (data[i-1].cmd == RlePacket::Repeat && data[i].len == 1 && data[i].cmd == RlePacket::Repeat &&
                (it = std::find(std::begin(lut), std::end(lut), _xor)) != std::end(lut))
        {
            sequence.push_back(it - lut);
            ++counter;
        }
        else
        {
            if (counter > 0)
            {
                result.push_back(RlePacket{RlePacket::XorSequence, (uint16_t)counter, 0, sequence});
            }

            sequence.clear();

            result.push_back(data[i]);
            counter = 0;
        }
    }
    assert(counter == 0);

    result.push_back(RlePacket{RlePacket::EndOfData, 0, 0, {}});

    int val = std::count_if(result.begin(), result.end(), [](const RlePacket& r) { return r.cmd == RlePacket::EndOfFrame; });
    if (val != 1)
    {
        dummy++;
    }

    return result;
}

std::vector<RlePacket> optimize_line_repeat(const std::vector<RlePacket>& data)
{
    std::vector<RlePacket> result;

    uint16_t counter = 0;
    uint16_t curval = 0;
    for (size_t i = 0; i < data.size(); ++i)
    {
        if (data[i].cmd == RlePacket::Repeat && data[i].len == height && counter == 0)
        {
            ++counter;
            curval = data[i].val;
        }
        else if (data[i].cmd == RlePacket::Repeat && data[i].len == height && data[i].val == curval)
        {
            ++counter;
        }
        else
        {
            if (counter > 0)
                result.push_back(RlePacket{RlePacket::RepeatLine, counter, curval});
            result.push_back(data[i]);
            counter = 0;
        }
    }
    assert(counter == 0);

    return result;
}

std::vector<RlePacket> optimize_raw_blocks(const std::vector<RlePacket>& data)
{
    std::vector<RlePacket> result;

    int counter = 0;
    for (size_t i = 0; i < data.size(); ++i)
    {
        if (data[i].cmd == RlePacket::Repeat && data[i].len == 1)
        {
            ++counter;
        }
        else
        {
            if (counter > 1)
            {
                std::vector<uint32_t> sequence;
                for (size_t j = i - counter; j < i; ++j)
                {
                    assert(data[j].cmd == RlePacket::Repeat);
                    assert(data[j].len == 1);
                    sequence.push_back(data[j].val);
                }
                assert(counter == sequence.size());
                result.push_back(RlePacket{RlePacket::RawBlock16, (uint16_t)counter, 0, sequence});
            }
            else if (counter == 1) // if only one block has been read, emit the block as-is
                result.push_back(data[i-1]);

            result.push_back(data[i]);
            counter = 0;
        }
    }
    assert(counter == 0);

    return result;
}

// TODO : special case to have single byte commands if the repeat length is short enough
uint32_t rle_size_calculator(const std::vector<RlePacket>& packets)
{
    uint32_t size = 0;
    for (const auto& packet : packets)
    {
        if (packet.cmd == RlePacket::Repeat)
        {
            if (packet.val == 0 || packet.val == 0xFFFF)
            {
                size += 1;
            }
            else if (packet.val <= 0xFF)
            {
                size += 2;
            }
            else
            {
                size += 3;
            }
            if (packet.len > 16)
                size += 1;
        }
        else if (packet.cmd == RlePacket::RepeatLine)
        {
            assert(packet.len <= width/16);
            size += 1;
        }
        else if (packet.cmd == RlePacket::ShiftedSequence)
        {
            if (packet.len == 1)
                size += 1;
            else
                size += 1 + packet.len/2 + packet.len%2;
        }
        else if (packet.cmd == RlePacket::RepeatShifted)
        {
            size += 2;
        }
        else if (packet.cmd == RlePacket::XorSequence)
        {
            if (packet.len == 1)
                size += 1;
            else
                size += 1 + packet.len/2 + packet.len%2;
        }
        else if (packet.cmd == RlePacket::RepeatXor)
        {
            if (packet.len == 1)
                size += 1;
            else
                size += 2;
        }
        else if (packet.cmd == RlePacket::RawBlock16)
        {
            size += 1 + 1 + packet.len*2;
        }
        else if (packet.cmd == RlePacket::EndOfFrame || packet.cmd == RlePacket::EndOfLine || packet.cmd == RlePacket::EndOfData)
        {
            size += 1;
        }
        else
            assert(false);
    }

    return size;
}

std::vector<uint8_t> rle_generate(const std::vector<RlePacket>& packets, int frame_number)
{
    std::vector<uint8_t> bytes;

    int frame_count = 0;
    unsigned size = 0;
    for (const auto& packet : packets)
    {
        if (packet.cmd == RlePacket::Repeat)
        {
            if (packet.len <= 16)
            {
                if (packet.val == 0 || packet.val == 0xFFFF)
                {
                    if (packet.val == 0)
                        bytes.push_back(0x80 | (packet.len-1));
                    else
                        bytes.push_back(0x90 | (packet.len-1));
                }
                // TODO : handle "0x**00" forms of words
                else if ((packet.val&0xFF) == 0)
                {
                    bytes.push_back(0xA0 | (packet.len-1));
                    bytes.push_back(packet.val >> 8);
                }
                else
                {
                    bytes.push_back(0xB0 | (packet.len-1));
                    bytes.push_back(packet.val >> 8);
                    bytes.push_back(packet.val&0xFF);
                }
            }
            else
            {
                bytes.push_back(0xD0);
                bytes.push_back(packet.len);
                bytes.push_back(packet.val >> 8);
                bytes.push_back(packet.val&0xFF);
            }
        }
        else if (packet.cmd == RlePacket::RepeatLine)
        {
            assert(packet.len <= width/16);
            if (packet.val == 0)
                bytes.push_back(0xD1);
            else if (packet.val == 0xFFFF)
                bytes.push_back(0xD2);
            else
            {
                bytes.push_back(0xD3);
                bytes.push_back(packet.val>>8);
                bytes.push_back(packet.val&0xFF);
            }
            bytes.push_back(packet.len);
        }
        else if (packet.cmd == RlePacket::ShiftedSequence)
        {
            if (packet.len == 1)
            {
                if (packet.mirrored)
                    bytes.push_back(0x10 | packet.sequence[0]);
                else
                    bytes.push_back(0x00 | packet.sequence[0]);
            }
            else
            {
                // emit packets of up to 16 words for simplicity and to avoid emitting a length byte
                for(size_t i = 0; i < packet.sequence.size(); i += 16) {
                    auto last = std::min(packet.sequence.size(), i + 16);
                    auto subseq = std::vector<uint32_t>(packet.sequence.begin() + i, packet.sequence.begin() + last);

                    if (packet.mirrored)
                        bytes.push_back(0xE0 | (subseq.size()-1));
                    else
                        bytes.push_back(0x60 | (subseq.size()-1));
                    for (size_t j = 0; j < subseq.size(); j += 2)
                    {
                        uint8_t byte = subseq[j];
                        if (j+1 < subseq.size())
                            byte |= (subseq[j+1] << 4);
                        bytes.push_back(byte);
                    }
                }
            }
        }
        else if (packet.cmd == RlePacket::RepeatShifted)
        {
            if (packet.mirrored)
                bytes.push_back(0x20 | packet.val);
            else
                bytes.push_back(0x30 | packet.val);
            bytes.push_back(packet.len);
            // require an explicit EOL byte if the shifted repetition takes the full height of the screen
            if (packet.len == height)
                bytes.push_back(0xD5);
        }
        else if (packet.cmd == RlePacket::XorSequence)
        {
            if (packet.len == 1)
            {
                assert(packet.sequence[0] < 16);
                bytes.push_back(0x40 | packet.sequence[0]);
            }
            else
            {
                // emit packets of up to 16 words for simplicity and to avoid emitting a length byte
                for(size_t i = 0; i < packet.sequence.size(); i += 16) {
                    auto last = std::min(packet.sequence.size(), i + 16);
                    auto subseq = std::vector<uint32_t>(packet.sequence.begin() + i, packet.sequence.begin() + last);

                    bytes.push_back(0xF0 | (subseq.size()-1));
                    for (size_t j = 0; j < subseq.size(); j += 2)
                    {
                        uint8_t byte = subseq[j];
                        if (j+1 < subseq.size())
                            byte |= (subseq[j+1] << 4);
                        bytes.push_back(byte);
                    }
                }
            }
        }
        else if (packet.cmd == RlePacket::RepeatXor)
        {
            if (packet.len == 1)
            {
                bytes.push_back(0x50 | packet.val);
            }
            else
            {
                bytes.push_back(0xC0 | packet.val);
                bytes.push_back(packet.len);
            }
        }
        else if (packet.cmd == RlePacket::RawBlock16)
        {
            // emit packets of up to 16 words for simplicity and to avoid emitting a length byte
            for(size_t i = 0; i < packet.sequence.size(); i += 16) {
                auto last = std::min(packet.sequence.size(), i + 16);
                auto subseq = std::vector<uint32_t>(packet.sequence.begin() + i, packet.sequence.begin() + last);

                assert(subseq.size() > 0 && subseq.size() <= 16);
                bytes.push_back(0x70 | (subseq.size()-1));
                for (auto word : subseq)
                {
                    bytes.push_back(word>>8);
                    bytes.push_back(word&0xFF);
                }
            }
        }
        else if (packet.cmd == RlePacket::EndOfFrame)
        {
            uint8_t audio_level = 0;
            if (frame_number < audio_data.size())
                audio_level = audio_data[frame_number];

            bytes.push_back(0xD4);
            bytes.push_back(audio_level); // audio bar height

            // add lyric information
            if (lyrics[next_lyric_idx].frame <= frame_number)
            {
                bytes.push_back(0xDA); // lyrics load
                bytes.push_back(lyrics[next_lyric_idx].text.size());
                for (auto c : lyrics[next_lyric_idx].text)
                    bytes.push_back(c);
                ++next_lyric_idx;
            }
            // lyric progress
            else
            {
                bytes.push_back(0xD9); // lyrics progress
                float progress = (frame_number - lyrics[next_lyric_idx-1].frame) /
                                 (float)(lyrics[next_lyric_idx].frame - lyrics[next_lyric_idx-1].frame);
                uint8_t progress_byte = progress*(lyrics[next_lyric_idx-1].text.size() << 3);
                bytes.push_back(progress_byte);
            }

            //bytes.push_back(frame_number >> 8);
            //bytes.push_back(frame_number&0xFF);
            ++frame_count;
        }
        else if (packet.cmd == RlePacket::EndOfLine)
        {
            bytes.push_back(0xD5);
        }
        else if (packet.cmd == RlePacket::EndOfData)
        {
            bytes.push_back(0xD6);
        }
        else
            assert(false);
    }

    assert(frame_count == 1);

    return bytes;
}

std::array<std::pair<int, int>, RlePacket::RleCommandEnd> rle_packet_info;
void rle_analysis(const std::vector<RlePacket>& rle)
{
    for (auto packet : rle)
    {
        rle_packet_info[packet.cmd].first++;
        rle_packet_info[packet.cmd].second += packet.len;
    }
}

std::vector<uint8_t> rle_data(const std::vector<uint32_t>& img)
{
    std::vector<uint8_t> data;
    uint32_t bit_count = 0;

    uint8_t acc = 0;
    int acc_capacity = 8;

    uint32_t command = 0;
    uint32_t last_command = 0;

    int ctrl_bits = 0;
    int val_bits = 0;

    auto add_bits = [&](uint32_t bits, int count, bool value = false)
    {
        // used for debugging and figuring out which commands are the most used
        if (value)
           bits = 0;

        while (count > 0)
        {
            if (acc_capacity > 0)
            {
                command <<= 1;
                command |= (bits >> (count-1)) &1;

                acc <<= 1;
                acc |= (bits >> (count-1)) &1;
                --acc_capacity;
                --count;
            }
            else if (acc_capacity == 0)
            {
                data.push_back(acc);
                acc = 0;
                acc_capacity = 8;
            }
        }
    };
    auto add_bits_ctrl = [&](uint32_t bits, int count)
    {
        add_bits(bits, count, false);
        ctrl_bits += count;
    };
    auto add_bits_value = [&](uint32_t bits, int count)
    {
        add_bits(bits, count, true);
        val_bits += count;
    };

    data.push_back(0x00); // Encoding type

    uint16_t mask = (factor == 8) ? 0xFF : 0xFFFF;
    uint32_t fact_log2 = (factor == 8) ? 3 : 4;
    uint16_t last_written = 0;

    uint32_t curval = img[0];
    uint32_t adjustedval = img[0] < 0x8000 ? 0 : mask;
    int run_length = 1;
    uint32_t start = 0;
    uint32_t last_explicit = 99999;
    int old_spare_counter = spare_counter;
    int transition_count = 0;

    // one additional iteration to collect the final command
    // Strive for a command_byte data_byte/word structure
    for (int i = 1; i < img.size()+1; ++i)
    {
        last_command = command;
        command = 0b1;

        uint32_t _xor = 0;
        uint16_t img_val = img[i];
        bool bypass_val = false;
        bool bypass_eol_marker = false;

        if ((i%height != 0) && i < img.size() && img[i] == img[i-1])
            ++run_length;
        else
        {
            _xor = last_written ^ curval;

            bool shifted_sequence = false;
            bool mirrored = false;
            int p;
            for (p = 0; p < factor; ++p)
            {
                uint16_t val = mask >> p;
                if (curval == val || curval == (~val&mask))
                {
                    mirrored = curval == (~val&mask);
                    shifted_sequence = true;
                    break;
                }
            }
            common_rle[run_length] += 1;


            if (run_length == 1 && shifted_sequence)
            {
                add_bits_ctrl(0b1, 1);
                add_bits_ctrl(p | (mirrored ? 0b10000 : 0), fact_log2+1);
                bypass_val = true;
            }
            else
            {
                add_bits_ctrl(0b0, 1);
                if (run_length <= 2)
                {
                    add_bits_ctrl(0b1, 1);
                    add_bits_ctrl(run_length-1, 1);
                }
                else if (run_length <= 8+2)
                {
                    add_bits_ctrl(0b01, 2);
                    add_bits_ctrl(run_length-2-1, 3);
                }
                // special case of a full line top to bottom
                else if (run_length == height)
                {
                    assert((start%height) == 0);
                    assert(i%height == 0);

                    add_bits_ctrl(0b001, 2);

                    // TODO : manually handle the rare case of this assert being incorrect

                    //assert(curval == 0 || curval == mask);
                    add_bits_ctrl(curval == 0 ? 0 : 1, 1);
                    bypass_val = true;
                    bypass_eol_marker = true;
                }
                else if (run_length <= 256)
                {
                    add_bits_ctrl(0b000, 3);
                    add_bits_value(run_length, 8);
                    assert(run_length <= height);
                }
            }

            if (acc_capacity < 8)
            {
                common_rle_val[acc_capacity] += 1;
                acc <<= acc_capacity;
                data.push_back(acc);
                acc_capacity = 8;
            }

            if (bypass_val)
                ;
            else if (curval != 0 && curval != mask)
            {
                uint16_t lut[16] = {0x2, 0x4000, 0x4, 0x2000, 0x8, 0x10, 0x800, 0x1000,
                                    0x20, 0x400, 0x100, 0x200, 0x40, 0x80, 0x8000, 0x1};

                uint16_t* it;
                if ((it = std::find(std::begin(lut), std::end(lut), _xor)) != std::end(lut))
                {
                    add_bits_ctrl(0b1, 1);
                    add_bits_value(it - lut, 4);
                }
                else
                {
                    if (shifted_sequence)
                    {
                        add_bits_ctrl(0b001, 3);
                        add_bits_value(p | (mirrored ? 0b10000 : 0), fact_log2+1);
                    }
                    else
                    {
                        uint16_t lut2[16] = {0x3000, 0xC, 0xC00, 0x300, 0xC0, 0x30, 0x600, 0x180,
                                            0x6, 0x6000, 0x18, 0x60, 0x1800, 0x3, 0xC000, 0xA};

                        if ((it = std::find(std::begin(lut2), std::end(lut2), _xor)) != std::end(lut2))
                        {
                            add_bits_ctrl(0b0001, 4);
                            add_bits_value(it - lut2, 4);
                        }
                        else
                        {
                            add_bits_ctrl(0b0000, 4);
                            add_bits_value(curval, factor);
                        }
                        //common_rle_val[curval <= 0xFF ? 1 : curval <= 0xFFF ? 2 : 0] += 1;
                    }
                }
            }
            else
            {
                add_bits_ctrl(0b01, 2);
                add_bits_ctrl(curval == 0 ? 0 : 1, 1);
            }

            //common_rle_val[curval] += 1;
            //if (frame_id == 1888)
                commands[command]++;
            if (command == 0xA00000 && last_command == command)
            {
                /*++transition_count;*/
            }

            assert(start/height == (start + run_length-1)/height); // make sure we're on the same column


            if (acc_capacity < 8)
            {
                common_rle_val[acc_capacity] += 1;
                acc <<= acc_capacity;
                data.push_back(acc);
                acc_capacity = 8;
            }

            // end of line bit
            if (i % height == 0 && !bypass_eol_marker)
            {
                // corresponds to a RLE length of [224-256], which is impossible as it's larger that the height of the image
                add_bits(0b10111110, 8);
                data.push_back(0b10111110);
            }

            last_written = curval;
            curval = img[i];
            run_length = 1;
            start = i;

            if (ctrl_bits > 8)
            {
                start = i;
            }
            do
            {
                ++spare_counter;
                ctrl_bits -= 8;
            } while (ctrl_bits > 0);
            do
            {
                ++spare_counter;
                val_bits -= 8;
            } while (val_bits > 0);

            ctrl_bits = val_bits = 0;
            ++transition_count;
        }
    }

    // end of frame marker
    // corresponds to a RLE length of [240-256], which is impossible as it's larger that the height of the image
    add_bits(0b10111111, 8); ++spare_counter;

    ++rle_passes;

    if (acc_capacity < 8)
    {
        acc <<= acc_capacity;
        data.push_back(acc);
    }

    //printf("%d / %d (%d)\n", data.size(), spare_counter - old_spare_counter, transition_count);
    return data;
}

int main()
{
    QFile audio_data_file("audio_data.bin");
    if (!audio_data_file.open(QIODevice::ReadOnly))
        return -1;
    audio_data = audio_data_file.readAll();

    const QString prefix = "320x200_nodither/";

    auto im0 = QImage(prefix + "frame-1.png");
    width = im0.width();
    height = im0.height();

    int x = 0, y = 0;
    int z = 40;


    std::vector<std::pair<int, int>> sizes;
    std::vector<int> best_nb_by_strat(11);

    std::vector<uint8_t> result_bytes;

    int current_cylinder = 0;
    int largest_diff = 0;
    int sum = 0;
    int diff_sum = 0;
    int n = 0;
    int other_counter = 0;
    int actual_real_counter = 0;
    uint32_t transition_acc = 0;
    for (int i = 1; i < 3286; ++i)
    {

        frame_id = i;

        auto im1_path = QString(prefix + "frame-%1.png").arg(i);
        auto im2_path = QString(prefix + "frame-%1.png").arg(i+1);
        assert(QFileInfo::exists(im1_path));
        if (!QFileInfo::exists(im1_path) || !QFileInfo::exists(im2_path))
            continue;

        int diff_pixels = 0;

        auto qim1 = QImage(im1_path).convertToFormat(QImage::Format_ARGB32);
        auto qim2 = QImage(im2_path).convertToFormat(QImage::Format_ARGB32);

        auto im1 = flatten(qim1);
        auto im2 = flatten(qim2);
        auto cim1_t = compress_transpose(qim1);
        auto cim2_t = compress_transpose(qim2);

        auto cim1 = compress8bit(im1);
        auto cim2 = compress8bit(im2);


        auto delta = cim2;
        for (unsigned i = 0; i < cim1.size(); ++i)
        {
            delta[i] ^= cim1[i];
        }
        auto delta_t = cim2_t;
        for (unsigned i = 0; i < cim1.size(); ++i)
            delta_t[i] ^= cim1_t[i];
        for (unsigned i = 0; i < cim1.size(); ++i)
        {
            if (cim1[i] != cim2[i])
                ++diff_pixels;
        }

        std::vector<RlePacket> rle = (rle_packets(cim1_t).size() < rle_packets(delta_t).size()) ? rle_packets(cim1_t)
                                                                                               : rle_packets(delta_t);

        transition_acc += rle.size();

        std::vector<RlePacket> rle_packed_arrays[2];

        for (int z = 0; z < 2; ++z)
        {
            rle_packed_arrays[z] = z == 0 ? rle_packets(cim1_t) : rle_packets(cim1_t);
            rle_packed_arrays[z] = optimize_line_repeat(rle_packed_arrays[z]);

            rle_packed_arrays[z] = optimize_shifted_sequences(rle_packed_arrays[z], true);
            rle_packed_arrays[z] = optimize_shifted_sequences(rle_packed_arrays[z], false);
            //rle_packed_arrays[z] = optimize_xor_sequences(rle_packed_arrays[z]);
            rle_packed_arrays[z] = optimize_xor_repeat(rle_packed_arrays[z]);
            rle_packed_arrays[z] = optimize_shifted_repeat(rle_packed_arrays[z], true);
            rle_packed_arrays[z] = optimize_shifted_repeat(rle_packed_arrays[z], false);
            rle_packed_arrays[z] = optimize_raw_blocks(rle_packed_arrays[z]);

        }

        std::vector<RlePacket> shifted_vals =
                (rle_packed_arrays[0].size() < rle_packed_arrays[1].size()) ?
                    rle_packed_arrays[0] :
                    rle_packed_arrays[1];

        rle_analysis(shifted_vals);
        other_counter += rle_size_calculator(shifted_vals);
        auto rle_byte_data = rle_generate(shifted_vals, i);
        actual_real_counter += rle_byte_data.size();

        if (i == 1492)
        {
            // is 822
            //printf("1692 is n %d\n", n);
            //return 0;
             z = 50;
        }

        uint32_t rle_1_t = rle_data(cim1_t).size();
        uint32_t rle_delta_t = rle_data(delta_t).size();

        uint32_t best = 9999999;

        best = std::min(best, rle_1_t);
        best = std::min(best, rle_delta_t);

        fflush(stdout);
        if (rle_delta_t == best)
            ++best_nb_by_strat[5];
        if (rle_1_t == best)
            ++best_nb_by_strat[1];


        assert(std::count_if(shifted_vals.begin(), shifted_vals.end(), [](const RlePacket& r) { return r.cmd == RlePacket::EndOfFrame; }) == 1);

        // if the next frame crosses a cylinder boundary, emit a "cylinder load" command
        if (result_bytes.size()/CYLINDER_SIZE != (result_bytes.size() + rle_byte_data.size())/CYLINDER_SIZE)
        {
            if (current_cylinder == FIRST_DISK_CYLINDERS - 1)
            {
                result_bytes.push_back(0xD8);
            }
            else
            {
                result_bytes.push_back(0xD7); // CylinderLoad
            }

            // padding until the next sector boundary
            while (result_bytes.size() % CYLINDER_SIZE != 0)
            {
                result_bytes.push_back(0xD4);
            }

            ++current_cylinder;
        }

        for (auto b : rle_byte_data)
        {
            result_bytes.push_back(b);
        }

        printf("Image %d, best %d, diff %d, packets %d, shifted %d\n", i, best, diff_pixels,
               std::min(rle_packets(cim1_t).size(), rle_packets(delta_t).size()),
               shifted_vals.size());
        sizes.push_back(std::make_pair<int>(shifted_vals.size(), i));
        //sizes.push_back(std::make_pair<int>(best, i));

        if (largest_diff < diff_pixels)
            largest_diff = diff_pixels;

        diff_sum += diff_pixels;
        sum += best;
        ++n;
    }

    result_bytes.push_back(0xD6); // EndOfData

    std::ofstream FILE("out.bin", std::ios::out | std::ofstream::binary);
    std::copy(result_bytes.begin(), result_bytes.end(), std::ostreambuf_iterator<char>(FILE));

    std::sort(sizes.begin(), sizes.end(), [](const auto& lhs, const auto& rhs){return lhs.first > rhs.first;});

    printf("Total : %fKB, mean %f, mean diff pixels %f, max diff %d\n", result_bytes.size()/1000.0f, sum/(float)n, diff_sum/(float)n, largest_diff);

    {
        std::vector<std::pair<std::pair<int, int>, int>> pairs;
        for (auto itr = length_sequences.begin(); itr != length_sequences.end(); ++itr)
            pairs.push_back(*itr);

        sort(pairs.begin(), pairs.end(), [=](std::pair<std::pair<int, int>, int>& a, std::pair<std::pair<int, int>, int>& b)
        {
            return a.second > b.second;
        });

        for (int i = 0; i < 20 && i < pairs.size(); ++i)
        {
            printf("<%d,%d> : %d\n", pairs[i].first.first, pairs[i].first.second, pairs[i].second);
        }

        printf("-----\n");
    }

    for (int i = 0; i < 20 && i < sizes.size(); ++i)
    {
        printf("%d : %d\n", sizes[i].first, sizes[i].second);
    }

    printf("-----\n");

    for (int i = 0; i < best_nb_by_strat.size(); ++i)
    {
        printf("%d : %d\n", i, best_nb_by_strat[i]);
    }

    printf("-----\n");

    {
        std::vector<std::pair<int, int>> pairs;
        for (auto itr = common_rle_val.begin(); itr != common_rle_val.end(); ++itr)
            pairs.push_back(*itr);

        sort(pairs.begin(), pairs.end(), [=](std::pair<int, int>& a, std::pair<int, int>& b)
        {
            return a.second > b.second;
        });

        for (int i = 0; i < 20 && i < pairs.size(); ++i)
        {
            printf("0x%X : %d (%f%%)\n", pairs[i].first, pairs[i].second, (double)pairs[i].second / spare_counter * 100.0);
        }

        printf("-----\n");
    }

    printf("-----\n");

    {
        std::vector<std::pair<int, int>> pairs;
        for (auto itr = common_rle.begin(); itr != common_rle.end(); ++itr)
            pairs.push_back(*itr);

        sort(pairs.begin(), pairs.end(), [=](std::pair<int, int>& a, std::pair<int, int>& b)
        {
            return a.second > b.second;
        });

        for (int i = 0; i < 20 && i < pairs.size(); ++i)
        {
            printf("%d : %d\n", pairs[i].first, pairs[i].second);
        }

        printf("-----\n");
    }

    printf("curvals : %d\n", common_rle_val.size());
    printf("Commands : %d\n", commands.size());

    {
        std::vector<std::pair<uint32_t, int>> pairs;
        for (auto itr = commands.begin(); itr != commands.end(); ++itr)
        {
            if (31 - __builtin_clz(itr->first) <= 8)
                continue;
            pairs.push_back(*itr);
        }

        sort(pairs.begin(), pairs.end(), [=](std::pair<uint32_t, int>& a, std::pair<uint32_t, int>& b)
        {
            return a.second > b.second;
        });

        for (int i = 0; i < 20 && i < pairs.size(); ++i)
        {
            printf("0x%X : %d\n", pairs[i].first, pairs[i].second);
        }

        printf("-----\n");
    }

    uint64_t cmd_len_sum = 0;
    uint64_t count_sum = 0;
    for (auto pair : commands)
    {
        count_sum += pair.second;
        cmd_len_sum += (31 - __builtin_clz(pair.first)) * pair.second;
        uint64_t len = (31 - __builtin_clz(pair.first));
    }
    printf("Mean command length : %f (total %d)\n", (cmd_len_sum)/(double)count_sum, count_sum);

    uint64_t len_sum = 0;
    count_sum = 0;
    for (auto pair : common_rle)
    {
        count_sum += pair.second;
        len_sum += (31 - __builtin_clz(pair.first)) * pair.second;
        uint64_t len = (31 - __builtin_clz(pair.first));
    }
    printf("Mean length : %f\n", (len_sum)/(double)count_sum);
    printf("Mean transitions : %f\n", transition_acc/(float)n);
    printf("byte count bis : %f\n", spare_counter/(float)rle_passes * n / 1000.0f);
    printf("byte count ter : %f\n", other_counter/1000.0f);
    printf("byte count real : %f\n", actual_real_counter/1000.0f);

    for (int i = 0; i < RlePacket::RleCommandEnd; ++i)
    {
        printf("Command type %d, %d occurences, mean len %f\n", i, rle_packet_info[i].first,
               rle_packet_info[i].second/(double)rle_packet_info[i].first);
    }

    printf("n : %d\n", n);
    printf("in data : %d\n", std::count(result_bytes.begin(), result_bytes.end(), 0xD4));
}
