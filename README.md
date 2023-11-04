# What is it
The single file here is an energy saving patch for Android version of KOReader app, working on Nook Glowlight 4/4e and probably some other models of eInk readers.

# Background
The screen and CPU is the most power hungry parts of a conventional smartphone. Android and other mobile systems take special care to minimize this. One of possible low-consumptions states is Deep Sleep (aka Doze, also I will call it DS here sometimes) mode when the screen is off and CPU basically switches off only to be lightly alert about some of events that might occur. Touching the screen or pressing the hardware buttons are the examples of such events. Most of modern smartphones use this mode, but for them having LCD screens, the mode is possible only when the screen is off.

But eInk devices has a different kind of screen that allows keeping the current image without need for the energy maintaining it. Together with Deep Sleep mode this allows a unique mode of usage when for a short period of time both the screen and CPU is fully working preparing and showing a page and then screen just doesn't consume energy naturally while CPU goes into the Deep Sleep mode. The latter period is obvisouly longer that the former so overall this strategy would theoretically allow saving much energy when reading a e-Book.   

The explained method looks natural and simple, but whether it is implemented and used on a particular device is an open question. The author used to own Nook Simple Touch where this was somehow implemented deep in the system and most of activities somehow naturally used this technique. It felt like the device might work forever on a single charge no matter what the reader app was used. Recently I started using Nook Glowlight 4e and my expectations about this was high. Unfortunately the device didn't meet them. Or rather met them partly. I should mention that the following observation was made having an excellent app Better Battery Stats as my companion (I will call it BBS). Most of side-loaded apps just worked with the CPU on full-time, no traces of DS whatsoever. But the bundled BN Reader app (bn.ereader) actually used this method according to statictics from BBS. The following investigation allowed me to find the algorithm this app was using. 

There's a system setting called `power_enhance_enable`. In order to send the device into DS one should change it first to `0` and then to `1`. After that, the system libraries will take of the rest and about 2 seconds later the device will be fully sleeping while keeping the screen image intact. Btw, when you press the power button and see the screesaver image, you will look at the result of the explained algorighm, since the system itself uses it for the stand by mode. 

This method works for Nook Glowlight 4/4e, but it also possible that it works for other modern eInk devices powered by Android. For example, [MobileScribe SDK](https://github.com/webpad/eNote-SDK) page mentions this setting and basically the method described.  

# The patch explained
My early attempts to implement this method for my Nook involved working with additional applications and Android tools in order to make this method univeral and working with any reader application. But the results were mixed. First, this kind of approach requires the device to be rooted. Second, inter-process communication while involving root-wrapped calls probably took some of the energy I was trying to save in the first place. But then I found that KOReader, my reader of application of choice, is actually capable of very sofisticated customization using Lua language and its sub-system allowing patching. So, this patch was born.   

How the patch is working
* it is installed as 'Phase 2' patch ([see the docs](https://github.com/koreader/koreader/wiki/User-patches)) after UIManager is ready
* It intercepts a method `onGotoViewRel` of two known modules of the reader. This method is used when the reader needs to show a new part of the text relative to the current one. This is the case both for tapping at the areas that take care of next/previous pages and for hardware buttons for listing.
* When the event is detected, the patch sets `power_enhance_enable` to `0` and  waits about 1 second (using the UIManager scheduler).
* After the one-second delay it sets `power_enhance_enable` to `1`.
* The rest is the system job. For successfully installed and working patch the device will be in the Deep Sleep state until a new touch and press event occures. 

What this patch allows
* My estimation is that you will probably get about 4000-6000 page turns per single charge. But obviusly no mass book is that big. So between the books you will probably have other activities on the device (like choosing a new book or uploading it) that unfortunately fully utilize CPU power while draining it. So, the real numbers may be different. 
* Notice that I'm talking here not about time (... hours per charge), but about page turns. This means that a little different style of reading is possible when you have your book opened and standing nearby and you lazily turn a attention from some main task to the book without locking and unlocking it. (Remember to increase screen off timeout for this, I will talk about it later)  

# How to install / how to use

* You don't need rooted device for this patch. Only KOReader should be installed and access to file manager in order to copy the patch to the required location.  
* You have to use the general version of KOReader. This app has a different [variant](https://f-droid.org/en/packages/org.koreader.launcher.fdroid/) installed through FDroid ecosystem. Probably due to extensive capabilities of the scripts, the developers decided to disable them for a version indended for the 'market' execting more secure software. The package is of the script-capable version is `org.koreader.launcher` and usually avaible throught the release links of the KOReader project site.
* You have to enable "Modify System Settings" permission in the KOReader app settings. KOReader (luckily for this patch) has this permission request for unrelated reasons, but it may be switched off by default or by the user. But don't worry if you forget to switch the setting, the patch will gracefully complain if it can't change the setting during the execution.
* Copy the patch to `/sdcard/koreader/patches` folder . The patches sub-folder is probably don't exist if you didn't install patches before so create it in this case.
* Restart KOReader. You have to fully restart the program. For this use the menu item 'Exit' available in the burger (right) menu.
* (Optional)
* (Optional) Increase the Screen Off Time Out value if you have plans for lazy reading. Screen Off time is the setting that sends the device in the locked state (with the screensaver image) after period of inactivity. It is usually small and with the official UI can be changed up to 1 hour. The lazy reading I described before is about leaving the reader with the current page shown and turning attention to something else until the you're ready to return to reading. If this period may be long, then the Screen Off time might fire before you return to reading so it's a good idea to increase it. 


