# RUBY DICOM

Ruby DICOM is a small and simple library for handling DICOM in Ruby. DICOM (Digital Imaging
and Communications in Medicine) is a standard for handling, storing, printing,
and transmitting information in medical imaging. It includes a file format definition
and a network communications protocol. Ruby DICOM supports reading from, editing
and writing to this file format. It also features basic support for select network
communication modalities like querying, moving, sending and receiving files.


## INSTALLATION

  gem install dicom


## REQUIREMENTS

* Ruby 1.9.3 (if you are still on Ruby 1.8, gems up to version 0.9.1 can be used)


## BASIC USAGE

### Load & Include

    require 'dicom'
    include DICOM

### Read, modify and write

    # Read file:
    dcm = DObject.read("some_file.dcm")
    # Extract the Patient's Name value:
    dcm.patients_name.value
    # Add or modify the Patient's Name element:
    dcm.patients_name = "Anonymous"
    # Remove a data element from the DICOM object:
    dcm.pixel_data = nil
    # Write to file:
    dcm.write("new_file.dcm")

### Modify using tag strings instead of dictionary method names

    # Extract the Patient's Name value:
    dcm.value("0010,0010")
    # Modify the Patient's Name element:
    dcm["0010,0010"].value = "Anonymous"
    # Delete a data element from the DICOM object:
    dcm.delete("7FE0,0010")

### Extracting information about the DICOM object

    # Display a short summary of the file's properties:
    dcm.summary
    # Print all data elements to screen:
    dcm.print
    # Convert the data element hierarchy to a nested hash:
    dcm.to_hash

### Handle pixel data

    # Retrieve the pixel data in a Ruby Array:
    dcm.pixels
    # Load the pixel data to an numerical array (NArray):
    dcm.narray
    # Load the pixel data to an RMagick image object and display it on screen (X):
    dcm.image.normalize.display

### Transmit a DICOM file

    # Send a local file to a server (PACS) over the network:
    node = DClient.new("10.1.25.200", 104)
    node.send("some_file.dcm")

### Start a DICOM server

    # Initiate a simple storage provider which can receive DICOM files of all modalities:
    s = DServer.new(104, :host_ae => "MY_DICOM_SERVER")
    s.start_scp("C:/temp/")

### Log settings

    # Change the log level so that only error messages are displayed:
    DICOM.logger.level = Logger::ERROR
    # Setting up a simple file log:
    l = Logger.new('my_logfile.log')
    DICOM.logger = l
    # Create a logger which ages logfile daily/monthly:
    DICOM.logger = Logger.new('foo.log', 'daily')
    DICOM.logger = Logger.new('foo.log', 'monthly')


### IRB Tip

When working with Ruby DICOM in irb, you may be annoyed with all the information
that is printed to screen, regardless if you have set verbose as false. This is because
in irb every variable loaded in the program is automatically printed to the screen.
A useful hack to avoid this effect is to append ";0" after a command.
Example:

    dcm = DObject.read("some_file.dcm") ;0


## RESOURCES

* [Official home page](http://dicom.rubyforge.org/)
* [Discussion forum](http://groups.google.com/group/ruby-dicom)
* [Documentation](http://rubydoc.info/gems/dicom/frames)
* [Tutorials](http://dicom.rubyforge.org/tutorials.html)
* [Source code repository](https://github.com/dicom/ruby-dicom)


## COPYRIGHT

Copyright 2008-2014 Christoffer Lervåg

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see http://www.gnu.org/licenses/ .


## ABOUT THE AUTHOR

* Name: Christoffer Lervåg
* Location: Norway
* Email: chris.lervag [@nospam.com] @gmail.com

Please don't hesitate to email me if you have any feedback related to this project!


## CONTRIBUTORS

* [Christoffer Lervåg](https://github.com/dicom)
* [John Axel Eriksson](https://github.com/johnae)
* [Kamil Bujniewicz](https://github.com/icdark)
* [Jeff Miller](https://github.com/jeffmax)
* [Donnie Millar](https://github.com/dmillar)
* [Björn Albers](https://github.com/bjoernalbers)
* [Felix Petriconi](https://github.com/FelixPetriconi)
* [Greg Tangey](https://github.com/Ruxton)
* [Cian Hughes](https://github.com/cian)
* [Steven Bedrick](https://github.com/stevenbedrick)
* [Lars Benner](https://github.com/Maturin)
* [Brett Goulder](https://github.com/brettgoulder)