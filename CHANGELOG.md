0.3.1b
---

* Tracking of unfollowers also in file
* No more @DEBUG, @WARNINGS, @ERRORS, only @verbose
* Changed another time the data structure file: Time written only 1 time
* Loading Colors imrpoved

0.3b
---

* Added first version of tracking unfollowers
* Optimized settings loading
* Optimized yaml file loading
* Now all data are saved in the file (customizable) "data"
* Whitelist moved into 'settings.rb' as array of screen_name
* Bugfix: friends_ids, followers_ids, to_remove were not cleaned after a cycle
* Added time2ago function in order to output better when cache expired
* Visual Bugfix: it was "^C[W] Pressed ..." now "[W] Pressed"
* CTRL+C exception now is always rescued

0.2b
---

* Added cache support
* Added cache timing and expiration support
* Added settings to customize cache and expiration delay (cache and cache_time)
* Added non-color terminal support in settings (use_colors)
* Code more clean with only one check_cache

0.1.1a
---

* Settings very more customizable, placed in settings.rb
* Detect first run, and ask for consumer key and secret

0.1a
---

* First release: unfollow who is not following you, downloading followers and friends (following) and deleting these accounts but verified or whitelisted accounts
