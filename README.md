# BadApple5150
A demo running the Bad Apple shadow-art animation on a IBM PC 5150.

![GIF](https://imgur.com/40cP685.gif)

## Running the demo

Using the excellent and accurate [86box](https://github.com/86Box/86Box) emulator is recommended.
Configure 86box according to the following settings:

![machine_settings](https://user-images.githubusercontent.com/8571612/158222579-ac71f966-6333-4040-a14c-fcbb8c7fa25d.png)
*Machine settings. Note: using the 1982 variant of the PC 5150 is necessary.*

![floppies](https://user-images.githubusercontent.com/8571612/158222583-f09ad99a-2a66-4e29-9645-2f6472b418e5.png)
*Floppy drive settings.*

![soundblaster](https://user-images.githubusercontent.com/8571612/158222586-a8bfd316-fd93-4e96-8eed-baf031935adb.png)
*Sound settings.*

![video_settings](https://user-images.githubusercontent.com/8571612/158222588-8ed4c0ce-a487-4fe0-9aac-84bff9177ee9.png)
*Video settings.*

Then, load the files *fat.img* and *fat2.img* onto the two floppy drives.

Run the machine, and enjoy!

## Building the demo

* Install the `mtools`, `nasm` and `gcc` packages using your favourite package manager.
* Execute the `build_script.sh` script in the `demo-source/` directory.
* If the build was successful, the files `fat.img` and `fat2.img` files should have been created in the `bin/` directory.
