# Contributing Code

So you want to contribute to ruby-dicom? That's great, thank you! If you are a
first time committer however, you must to take a moment to read these instructions.

The preferred method, by far, is to convey your code contribution in the form
of a [github](https://github.com/dicom/ruby-dicom) pull request.

## Committer's Recipe

* Fork the repository (for bonus points, use a topical branch name).
* Execute the specification (rspec tests) to verify that all spec examples pass
  (if in doubt, check out the rakefile for instructions).
* Add a spec example for your change. Only refactoring and documentation changes
  require no new tests. If you are adding functionality or fixing a bug, a test is mandatory!
* Alter the code to make the new spec example(s) pass.
* Keep it simple! One issue per pull request. Mixing two or more independent
  issues in the same pull request will complicate the review of your request and
  may result in a rejection (even if individual components of the commit are sound).
* Don't modify the version string or the Changelog.
* Push to your fork and submit a pull request.
* Wait for feedback (this shouldn't take too long). The pull request may be accepted right
  away, it may be rejected (with a reason specified), or it may spark a discussion where
  changes/improvements are suggested in order for the pull request to be accepted.

## Guidelines

In order to increase the chances of your pull request being accepted,
please follow the project's coding guidelines. Ideally, your contribution must not
add [technical debt](http://en.wikipedia.org/wiki/Technical_debt) to the project.

* Provide thorough documentation. It should follow the format used by this project
  and give information on parameters, exceptions and return values where relevant.
  Provide examples for non-trivial use cases.
* Read the excellent [Github Ruby Styleguide](https://github.com/styleguide/ruby)
  if you are new to collaborative Ruby development. Do note though, that we actually
  don't follow all styles listed yet (perhaps we should?!).
* Some sample patterns of ours:
  * Indentation: Two spaces (no tabs).
  * No trailing whitespace. Blank lines should not have any space.
  * Method parameters: my_method(my_arg) is preferred instead of my_method( my_arg ) or my_method my_arg
  * Assignment: a = b and not a=b
* In general: Follow the conventions you see used in the source code already.

## Contribution Agreement

ruby-dicom is licensed under the [GPL v3](http://www.gnu.org/licenses/gpl.html),
and to be in the best position to enforce the GPL, the copyright status of ruby-dicom
needs to be as simple as possible. To achieve this, contributors should only provide
contributions which are their own work, and either:

a) Assign the copyright on the contribution to myself, Christoffer Lervåg

or

b) Disclaim copyright on it and thus put it in the public domain

Copyright assignment (a) is the preferred and encouraged option for larger
code contributions, and is assumed unless otherwise is specified.

Please see the [GNU FAQ](http://www.gnu.org/licenses/gpl-faq.html#AssignCopyright)
for a fuller explanation of the need for this.

## Credits

All contributors are credited, with full name and link to their github account,
in the README file. If such an accreditation is not wanted (for whatever reason),
please let me know so, either in the pull request or in private.


# Other ways to contribute

Not ready to get your hands dirty with source code and git? Don't worry,
there are other ways in which you can contribute to the project as well!

* Create an issue on github for feature requests or bug reports.
* Weigh in with your opinion on existing issues.
* Write a tutorial.
* Answer questions, or tell the community about your exciting ruby-dicom projects in the
  [mailing list](http://groups.google.com/group/ruby-dicom).
* Academic works: Properly reference ruby-dicom in your work and tell us about it.
* Spread the word: Tell your colleagues about ruby-dicom.
* Make a donation.