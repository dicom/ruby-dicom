# 0.9.6

## 20th June, 2014

* Fixed an issue where role negotiation in the network code would cause an exception.
* Fixed an issue where a C-Move request could terminate instead of properly waiting for a receipt.
* Fixed an issue where network code would hang waiting for a response when it doesn't get any.
* Automatically load RMagick/mini_magick when using the image methods, to avoid confusing exceptions.
* Made json and yaml gem dependencies, to avoid unexpected exceptions when using the #to_json and #to_yaml methods.
* Give a warning instead of raising an error when Parent#delete and #value gets an obviously invalid argument.
* Introduced Parent#representation, giving a description of the parent objects Sequence, Item & DObject.
* Refactored various methods for improved code simplicity.
* Upgraded specification to use RSpec 3.
* Changed information files from RDoc to Markdown format.
* Performance improvement when writing DICOM string segments.
* Changed element and uid dictionaries from .txt to .tsv.
* Bumped required Ruby version to 1.9.3.
* Replaced the custom encoding/decoding of big endian numbers with the Ruby standard library implementation.


# 0.9.5

## 26th March, 2013

* DICOM module:
  * Use hyphen instead of underscore in ruby-dicom application title.
  * Added the DICOM load module method, a flexible method for loading DICOM data:
    * Accepts one or more directories (in which all files are scanned).
    * Accepts one or more file paths (which are loaded as DICOM objects).
    * Accepts one or more DICOM objects, which are called with #to_dcm and returned.
* Network:
  * Bind the DServer to '0.0.0.0' by default to avoid Econnrefused issues.
  * Significantly improved network receive performance.
  * Enable adding private UIDs to ruby-dicom's DICOM library.
  * Read element and UID dictionaries with UTF-8 encoding.
* DObject (/Item):
  * Added DObject#anonymize for easy anonymization of a single DICOM object.
  * Added add_element and add_sequence methods for conveniently creating new elements/sequences belonging to a specific DObject or Item.
  * Fixed an issue where the NArray library where needed when trying to pass an array to the pixels= method.
  * Fixed an issue where both Magick libraries where needed when trying to pass an image object to the image= method.
  * Added DObject#was_dcm_on_input attribute to separate between file and DObject elements given to DICOM::load.
  * Added option :include_empty_parents to DObject#write.
  * Removed the deprecated DObjet#write :add_meta option.
  * Added DObject#source attribute for keeping track of a DICOM object's origin.
  * Defaults to ignoring duplicate data elements and sequences instead of replacing the original element.
  * Added the :overwrite option to DObject#read and #parse which makes ruby-dicom overwrite elements when duplicates are encountered.
* Anonymizer:
  * Added Anonymizer#to_anonymizer, as well as equality and state methods.
  * Use 'O' instead of 'N' as the default replacement value for Patient's Sex.
  * Added :random_file_name option for increased security in the case of sensitive file name information.
  * Make all Anonymizer attributes accessible through options with Anonymizer#new.
  * Removed the deprecated identity_file feature.
  * Deprecated Anonymizer#execute, along with its accompanying methods.
  * Added the Anonymizer#anonymize method, which is intended to replace the execute method.
  * Improved the Anonymizer's conformance with the guidelines in the DICOM standard:
    * Delete the File Meta Information group (0002) on anonymization.
    * Add the Patient Identity Removed element with value 'YES'.
    * Add de-identification method code sequence.
    * Added 7 new elements to the default anonymization list.
  * Enabled complete remapping of UIDs in the Anonymizer (keeping all references between files/series/studies valid).
  * Added Anonymizer :recursive option, for anonymizing entire element trees (not just the top level).
  * Added Anonymizer :encryption option, which allows the simulatenous preservation of privacy and key/value relations in the audit file.


# 0.9.4

## 10th September, 2012

* Converted the documentation format from RDOC to YARD.
* Removed deprecated remove_* methods (use the delete_* versions instead).
* Added the Parent#delete_retired method which makes it trivially easy to delete all retired elements/sequences from a DICOM file.
* Added a method to add a private dictionary to ruby-dicom's dictionary with LIBRARY#add_element_dictionary(file). The file must have the same tab separated format as ruby-dicom's element dictionary.
* Renamed the DICOM::UID constant to DICOM::UID_ROOT.
* Refactored the dictionary/DLibrary code and introduced two new classes: DictionaryElement and UID.
* Fixed an issue where the presence of the 'FFFC,FFFC' element in a DICOM file with compressed pixel data would result in a read failure.
* Updated the data dictionary to the 2011 edition.
* Replaced the Ruby coded dictionary with a pure tab separated text file.
* Added a script for generating a data dictionary based on the DICOM Standard documents published by NEMA.
* Fixed an issue where data elements which are specified by a range in the dictionary ('xx') where not properly recognized.
* Improved handling of non-string values in the Anonymizer (e.q. use an integer/float by default where applicable instead of a string).
* Implemented dynamic typing for data element values (e.q. converting a decimal string '2' to an integer).
* Added a missing pad byte for the 'BY' value representation.
* Made ruby-dicom encoding aware (using the Specific Character set tag) and return all element values encoded with UTF-8.
* Refactored read and write code to get rid of the 'private' DRead and DWrite classes.


# 0.9.3

## 6th May, 2012

* Deprecated all #remove* methods (replaced with #delete*) to increase consistency with Ruby.
* Changed preferred DObject variable name from obj to dcm for all examples.
* Added comparison methods (#==, #eql? and #hash) as well as dynamic #to_* methods to DObject, Element, Item & Sequence classes.
* Fixed incorrect handling of 3D pixel data with NArray (regression introduced in v0.8).
* Anonymizer can take a list of tags to be entirely deleted from the DICOM files during anonymization.
* Added Accession Number to default list of tags that are anonymized.
* Added a generate_uid method for creating custom (but valid) UIDs.
* Added an Anonymizer AuditTrail feature based on JSON, which will replace the (deprecated) identity_file feature.
* Implemented a proper UID anonymization with AuditTrail support and preservation of relations.
* Fixed and improved logging when failing to decompress pixel data.
* DServer defaults to bind to 127.0.0.1, with an option available for other bindings.
* More robust handling of invalid AT Element values when parsing DICOM files.
* Optimizations and code cleanups allowed by the introduced Ruby 1.9 requirement.


# 0.9.2

## 10th Oct, 2011

* Enabled the use of lower case tag letters in methods which previously required the use of upper case letters.
* Added new DObject class methods to offload DObject#new:
  * DObject#read is the new preferred method for reading a DICOM file.
  * DObject#parse is the new preferred method for parsing an encoded DICOM string.
  * The experimental feature of retrieving a DICOM file through http was moved to DObject#get.
  * Calling DObject with a string argument was deprecated.
* Introduced proper logging capabilities which replaced the simple message printouts to STDOUT:
  * Based on the Logger class of the Ruby Standard Library.
  * Automatically integrates with the Rails logger in a Rails application.
  * Supports information levels, logging to file, and more as available in the Ruby Logger.


# 0.9.1

## 27th May, 2011

* Fixed a regression in 0.9 where ruby-dicom would cause a Rails application to crash.


# 0.9

## 17th May, 2011

* Fixed an issue where data elements added to a DObject didn't get their endianness updated.
* Added the ability to encode/decode 32 bit pixel data.
* Added the ability to encode/decode big endian signed integers.
* Added the remove_children() method to parent elements.
* Added the ability to decode color images.
* Added the ability to retrieve multiple pixel frames as image objects.
* Added a :level option to the image retrieval methods which accepts custom window center/width values.
* Renamed the :rescale option to :remap in the image retrieval methods.
* Added the ability to decode RLE and JPEG Baseline compressed images.
* Added a specification test suite (using rspec and mocha).
* Implemented proper handling of data element values with VR "AT" (tag references).
* Changed the specification for Item indices (now starts at 0).
* Introduced the concept of ImageProcessors to replace the previously integrated RMagick image methods:
  * The user can select which ImageProcessor to be used at run-time.
  * Initially supported ImageProcessors: RMagick and mini_magick.
  * Additional ImageProcessors can easily be added using existing template.
  * Major refactoring and simplification of all image related code.
* Some changes of the Anonymizer class:
  * Added a :verbose option.
  * Added enum(), set_tag() and value() methods.
  * Removed add_tag, change_enum() and change_value() methods.
  * Added a log attribute.
* Fixed an issue where using a transfer syntax option with a binary string did not result in a correct application of the supplied syntax.
* Added a .dcm extension to DICOM files received by DServer.
* Fixed an issue where sending DICOM files with compressed pixel data resulted in an invalid DICOM transfer.
* Changed the specification to allow the query methods of DClient to accept any tag as a query parameter.
* Improved the handling of parent-child relations so these are always properly updated when adding, removing or changing parent elements.
* Renamed the following classes/modules:
  * SuperParent -> Parent
  * SuperItem -> ImageItem
  * DataElement -> Element
  * Elements -> Elemental
* Replaced ImageItem#image_properties() with num_cols(), num_rows() and num_frames().
* Renamed the following ImageItem methods:
  * get_image_magick() -> image()
  * get_images_magick() -> images()
  * set_image_magick() -> image=()
  * get_image() -> pixels
  * get_image_narray -> narray
  * set_image -> pixels=()
  * set_image_narray -> pixels=()
* Added the following conversion methods to DObject, Sequence, Item & Element:
  * inspect()
  * to_hash()
  * to_json()
  * to_yaml()
* Added the ability to use DICOM element names as methods for creating, editing and deleting elements.
* Added the ability to read a DICOM file from a http string, using open-uri (experimental).
* Added alias_methods read? for read_success and written? for write_success in DObject.
* Renamed DObject#information() to summary().
* Added various ArgumentError exceptions to facility easier debugging.
* Various bug fixes.


# 0.8

## 1st August, 2010

* Overall changes:
  * A complete rewrite of data element handling has resulted in a substantially different syntax and significantly cleaner and simpler code.
  * Greatly increased speed in DICOM object interaction. Especially noticeable on larger DICOM files.
  * A complete overhaul of the documentation has resulted in a consistent RDoc-style documentation across all classes/modules.
  * Increased use of module constants for improved code readability.
  * Major cleanup of codes and comments to make it consistent with Ruby 'best practice' guidelines.
  * Ready for Rails 3 (compatible with Bundler).
* Resulting from the rewrite is a number of new classes and modules for handling the various data objects:
  * DataElement: Ordinary data elements are instances of this class.
  * Item: Item elements are instances of this class.
  * Sequence: Sequence elements are instances of this class.
  * SuperItem: Methods which are shared between DObject and Item (mostly image related methods).
  * SuperParent: Methods which are shared between all parent objects (DObject, Item & Sequence).
  * Elements: A mix-in module used by all element objects (DataElement, Item & Sequence).
* DObject:
  * Completely rewritten data element handling.
  * Rewritten print() method with improved tree structure visualization, item indices and the ability to run on any parent element.
  * Renamed the print_properties() method to information(), and improved the amount of information outputted.
  * Removed the following methods: get_frames(), get_image_pos(), get_pos(), get_value(), get_bin(), set_value()
  * Renamed get_pixels() method to decode_pixels().
  * Replaced get_value() with value(). The set_value() method is replaced by the new() methods of DataElement, Sequence and Item classes.
  * Added the ability to add items at a specific index (shifting any existing items to appear after the inserted item).
  * Added the transfer_syntax=() method for changing the transfer syntax of a DICOM object.
  * Implemented a more robust padding of data element values with odd length, based on data element VR.
  * Added methods for removing all sequences, removing selected groups and returning all data elements of a selected group.
  * Optimized the get_image_narray() method to more efficiently return the pixel data.
  * Refined the print_all convenience method to call both print() and information().
* DRead:
  * More robust against crashing when parsing invalid files by proper use of exception handling.
  * Fixed some cases where a failed read where incorrectly marked as successful.
  * Increased compatibility (handles DICOM files saved with explicit syntax but no transfer syntax tag).
  * Explicit DICOM files with data elements of type "OF" are now handled correctly (both read and write).
* DWrite:
  * Simplified code and execution by removing group lengths (deprecated in the DICOM standard) and using undefined length for sequences/items.
  * More flexible insertion of missing meta group elements.
* Dictionary:
  * Some minor text corrections.
* Anonymizer:
  * Anonymizations executes much faster thanks to the work done with DObject data element handling.
  * Only top level data elements can be anonymized.
* DClient:
  * Can transmit multiple DICOM files at once with the send() method, which now will accept both DObjects and file strings.
  * Added the echo() method for performing a C-ECHO-RQ against a SCP.
* DServer:
  * Support for role negotiation.
  * Properly returns called AE title in association response.
  * The lists of acceptable abstract and transfer syntax can now be easily modified by the user.
  * Receiving multiple files (like an entire series, or study) in a single association is now supported.
  * Properly receives and responds to a C-ECHO-RQ.


# 0.7

## 28th February, 2010

* Added set_image() and set_image_narray() methods to write pixel data to the DICOM object, complementing set_image_magick().
* Added method get_image() which retrieves pixel data to a standard Ruby Array.
* Added a method for removing all private data elements in the DICOM object.
* Anonymizer class has gained the ability to remove all private data elements when anonymizing.
* Fixed an issue where Anonymizer failed to anonymize tags which had multiple instances in a DICOM file.
* Fixed an issue where Anonymizer failed to honor an expception folder if it ended with a file separation character.
* Private data elements can now be added to a DICOM object.
* Created a new FileHandler class where the user can customize the way incoming DICOM files are handled in DServer.
* Methods set_image_narray() and set_image_magick() takes options :min and :max to rescale pixel values.
* The magick and narray image retrieval methods now takes the option :rescale to convert pixel values to presentation values.
* Method get_pos() now takes the option :parent to narrow a search down.
* Improved the set_value() method to handle the creation of data elements inside sequences/items.
* All DObject methods who return Data Element positions now return an empty array instead of false if no matches are found.
* Improved handling of private tags in the library.
* Network transmissions with implicit encoding are now handled properly.
* Improved the handling of associations in the networking code.
* Some minor formatting improvements to the print() method.
* Improve the logic of updating group/sequence/item lengths to handle changes to Data Elements in sequence hierarchies.
* DLibrary class is permanently loaded when the gem is loaded and no longer needs to be specified by the user.
* Method get_image_magick() now handles pixel representation and window leveling.
* Program files was moved to a sub-directory and a module version string added, in accordance with gem guidelines.
* Renamed DObject attribute :types to :vr in accordance with the terminology of the official DICOM standard.
* Renamed method get_raw() to get_bin() and attribute :raw to :bin.
* Renamed get_pos() option :array to :selection.
* Updated Dictionary in accordance with the 2009 version of the official DICOM base standard.
* Various "under the hood" improvements and code cleanups.


# 0.6.1

## 23rd August, 2009

* Fixed a bug (introduced in version 0.6) where the creation of new data elements caused an error.
* Fixed a bug (introduced in version 0.6) where compressed pixel data were no longer detected correctly.
* Fixed a bug where writing a DICOM file with no path prefix failed.
* Fixed a bug where creating a new data element in a DICOM file with tag hierarchies gave an invalid DICOM file.
* Fixed a bug where retrieving a RMagick image from DICOM files containing two sets of image data failed.


# 0.6

## 13th August, 2009

* Complete rewrite of encoding/decoding to reduce code duplication and simplify the code.
* General optimizations to improve speed and reduce code complexity.
* Rewrote Dictionary to use Hash instead of Array. This has significantly improved the read speed of the library.
* Ruby DICOM now automatically strips away trailing whitespace when decoding string values.
* Introducing basic, experimental network functionality.
* The new DClient class enables features such as query, move and send.
* The new DServer class presents the ability to set up a simple storage server (Service Class Provider).


# 0.5

## 4th May, 2009

* Several small changes have been made to achieve compatibility with both Ruby versions 1.8 and 1.9.
* Implemented a change in syntax for several methods with a goal of simplification.
* Implemented a change in syntax for some methods, variables and messages in order
  to better match the terminology used in the official DICOM documents.
* Added a new attr_reader :errors, an array that holds any warnings issued during your
  interaction with DObject.
* DObject has received new attr_readers for the arrays holding information on the DICOM object.
  See documentation for details.
* Several methods have been cleaned up, making execution in some cases somewhat snappier.
* Several methods have been made more robust.
* Added new option :partial to the get_pos() method, which will enable search for partial string matches.
* Added new option :array to the get_value() and get_raw() methods which enables easy extraction of
  multiple values of a given tag to an array (relevant for tags present at multiple places in a DICOM file).
* Fixed a bug where exception folders where ignored in the Anonymizer class.


# 0.4

## 3rd February, 2009

* Change of syntax: Options are now supplied as hash.
* Method below() renamed to children().
* Added method parents() which returns the position of all items/sequences that are the parent of
  the specified tag. This method is only relevant for DICOM tags that exist inside a hierarchy.
* Simplified the code in class Dictionary: load time is ~ 40 times faster!
* Improved the code in class DRead: average read time is reduced by ~ 15 %.
* Improved support for Big Endian DICOM files.
* Added support for the "FL" (floating point single) value representation.
* Fixed a small bug with tag 0028,3006 in Dictionary.
* New method image_to_file() which makes it even easier than before to dump the DICOM pixel data to file.
* Introducing DWrite class which enables writing DICOM objects to file.
* Added several methods in DObject class to take advantage of write capability:
  remove_tag()
  set_value()
  set_image_magick()
  set_image_file()
  write_file()
* Introducing the Anonymizer class, which takes advantage of the new write capability in Ruby DICOM
  to offer a fairly powerful and customizable tool for anonymizing your DICOM files.


# 0.3

## 12th October, 2008

* The DRead class is now able to keep track of the position of the tags inside the hierarchy of sequences and items.
* DObject class has seen a number of improvements to allow taking advantage of this hierarchy awareness:
* Method get_pos() now can take an array of positions as an argument when searching for tags,
  meaning it will only search for hits amongst the positions provided.
* Method print() has been improved with new options to visualize the tree structure of the DICOM file.
* Method print() is able to print to file as well. The text file will be put in the same folder as the DICOM file.
* New method below(), which lets you specify a sequence or item, and this method will return the position
  of all tags contained in this sequence/item.
* Method print_properties() have been updated to display more information about the DICOM object.


# 0.2

## 10th August, 2008

* Data dictionary has been upgraded and is now compliant to the official standard.
* New DLibrary class which handles all interaction with the dictionary.
* Dictionary can be loaded before reading files, which will considerably speed up the process if reading multiple files.
* Reading compressed pixel data into an RMagick object is supported in principle, although it lacks proper testing at this point.
* DRead class is more resistant to breaking if it is handed a faulty file to read, and will return an error message instead of halting execution.
* Added option to load DICOM object in verbose or silent mode.


# 0.1

## 20th July, 2008

First public release.
The library does have several known issues and lacks some features I would like it to have, but it does
offer basic functionality and should be usable for people interested in working with DICOM files in Ruby.
The reading algorithm has been tested successfully with some 40 different DICOM files, so it should be fairly robust.