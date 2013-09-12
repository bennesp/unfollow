Unfollow.rb
====
This is my first scripts with Twitter REST API

What does it do?
---
It unfollow on Twitter all people aren't following you, except for

*   Verfied Accounts
*   Whitelisted Users in 'whitelist' file

Script is very configurable, you can modify your settings in settings.rb to:

* hide debug information
* hide warnings information
* hide errors information
* change tokens file
* change consumer public and secret keys

How to start? (Ruby and Needed Gems Installation)
---

First you must have ruby, and installed this gems:

* oauth
* twitter
* yaml

### Ubuntu and Debian-based

On Ubuntu simply run

``` $ sudo apt-get install ruby```

``` $ sudo gem install oauth twitter yaml```

### Othres Linux Distros

Install ruby and gem with your package manager or from source, and run from root 
``` # gem install oauth twitter yaml ```

### Windows

On Windows

* Download ruby from http://rubyinstaller.org/
* Run from cmd.exe with administrator rights: ``` > gem install oauth twitter yaml  ```

Run!
---

Now you can run ``` $ ruby unfollow.rb ``` to configure it and unfollow who's not following you!!
