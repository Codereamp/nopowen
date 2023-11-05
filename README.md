# What is it
The single file here is an energy saving patch for Android version of KOReader app, working on Nook Glowlight 4/4e and maybe on some other models of eInk readers. The patch recreates the same system actions as the native Nook app (bn.ereader) does between page turns. 

# Background
The screen and CPU is the most power hungry parts of a conventional smartphone. Android and other mobile systems take special care to minimize this. One of possible low-consumptions states is Deep Sleep (aka Doze, also I will call it DS here sometimes) mode when the screen is off and CPU basically switches off only to be lightly alert about some of events that might occur. Touching the screen or pressing the hardware buttons are the examples of such events. Most of modern smartphones use this mode, but with LCD screens the mode is possible only when the screen is completely off.

But eInk devices has a different kind of screen that allows keeping the current image without need for the energy maintaining it. Together with Deep Sleep mode this allows a unique mode of usage when for a short period of time both the screen and CPU is fully working preparing and showing a page and then screen just doesn't consume energy naturally while CPU goes into the Deep Sleep mode. The latter period is obvisouly longer that the former so overall this strategy would theoretically allow saving much energy when reading a e-Book.   

The explained method looks natural and simple, but whether it is implemented and used on a particular device is an open question. The author used to own Nook Simple Touch where this was somehow implemented deep in the system and most of activities somehow naturally used this technique. It felt like the device might work forever on a single charge no matter what the reader app was used. Recently I started using Nook Glowlight 4e and my expectations about this was high. Unfortunately the device didn't meet them. Or rather met them partly. I should mention that the following observation was made having an excellent app Better Battery Stats as my companion (I will call it BBS). Most of side-loaded apps just worked with the CPU on full-time, no traces of DS whatsoever. But the bundled BN Reader app (bn.ereader) actually used this method according to statictics from BBS. The following investigation allowed me to find the algorithm this app was using. 

There's a system setting called `power_enhance_enable`. In order to send the device into DS one should change it first to `0` and then to `1`. After that, the system libraries will take of the rest and about 2 seconds later the device will be fully sleeping while keeping the screen image intact. Btw, when you press the power button and see the screesaver image, you will look at the result of the explained algorighm, since the system itself uses it for the stand by mode. 

This method works for Nook Glowlight 4/4e, but it also possible that it works for other modern eInk devices powered by Android. For example, [MobileScribe SDK](https://github.com/webpad/eNote-SDK) page mentions this setting and basically the method described.  

# The patch explained
My early attempts to implement this method for my Nook involved working with additional applications and Android tools in order to make this method univeral and working with any reader application. But the results were mixed. First, this kind of approach requires the device to be rooted. Second, inter-process communication while involving root-wrapped calls probably took some of the energy I was trying to save in the first place. Then I found that KOReader, my reader of application of choice, is actually capable of very sofisticated customization using Lua language and its [patching feature](https://github.com/koreader/koreader/wiki/User-patches). So, this patch was born.   

How the patch is working
* it is installed as 'Phase 2' patch ([see the docs](https://github.com/koreader/koreader/wiki/User-patches)) after UIManager is ready
* It intercepts a method `onGotoViewRel` of two known modules of the reader. This method is used when the reader needs to show a new part of the text relative to the current one. This is the case both for tapping at the areas that take care of next/previous pages and for hardware buttons for listing.
* When the event is detected, the patch sets `power_enhance_enable` to `0` and  waits about 1 second (using the UIManager scheduler).
* After the one-second delay it sets `power_enhance_enable` to `1`.
* The rest is the system job. For successfully installed and working patch the device will be in the Deep Sleep state until a new touch and press event occures. 

What this patch allows
* My estimation is that you will probably get about 3000-5000 page turns per single charge. But obviusly no mass book is that big. So between the books you will probably have other activities on the device (like choosing a new book or uploading it) that unfortunately fully utilize CPU power while draining it. So, the real numbers may be different. To convert turns into time let's assume that you consume a single page after half a minute. Then the time estimate for 3000-5000 turns will be 25-40 hours of continous reading. To compare, the usual duration of the reading session in KOReader without this script is about 6-10 hours.    
* Notice that I'm talking here not about time (... hours per charge), but about page turns. This means that a little different style of reading is possible when you have your book opened and standing nearby and you lazily turn a attention from some main task to the book without locking and unlocking it. (Remember to increase screen off timeout for this, I will talk about it later)  

# How to install / how to use

Main requirements/steps

* You need Nook Glowlight 4/4e, maybe other Nooks of this generation. The setting I explained is very specific for particular OEM software stack so you may try on other devices and report the results. Another unknown device that magically support this method should be Ntx/AllWinner based and using Android verion around 8.  
* You don't need a rooted device for this patch. Only KOReader should be installed and access to file manager in order to copy the patch to the required location.  
* You have to use the general version of KOReader. This app has a different [variant](https://f-droid.org/en/packages/org.koreader.launcher.fdroid/) installed through FDroid ecosystem. Probably due to extensive capabilities of the scripts, the developers decided to disable them for a version indended for a 'market' with high secure expectations. The package is of the script-capable version is `org.koreader.launcher` and usually avaible throught the release links of the KOReader project site.
* You have to enable "Modify System Settings" permission in the KOReader app settings. KOReader (luckily for this patch) has this permission request for unrelated reasons, but it may be switched off by default or by the user. But don't worry if you forget to switch the setting, the patch will gracefully complain if it can't change the setting during the execution.
* Copy the patch to `/sdcard/koreader/patches` folder . The patches sub-folder is probably don't exist if you didn't install patches before so create it in this case.
* Restart KOReader. You have to fully restart the program. For this use the menu item 'Exit' available in the burger (right) menu.

Additional (optional) advanced steps

* I noticed that by default my Nook was using `CPU Governor` set to `performance`. This meant that the CPU was constantly clocking at 1.8 Ghz that supposedely drained battery at the peak when the CPU was working. My recommendation is to set it to `interactive`. The tests showed that in this case most of the time the CPU is clocked at 480 Mhz, while occasionally going to 1.2 GHz. This should have save about 30-50% of the battery for the state when the CPU is fully awake (Short periods of actually turning pages on the screen). Other variants of this settings that might suite you are `conservative` and `powersave`. But to change this setting you probably need to root your device. For changing this setting I used [Kernel Adiutor](https://f-droid.org/en/packages/com.nhellfire.kerneladiutor/) 
* Increase the Screen Off Time Out value if you have plans for lazy reading. Screen Off time is the setting that sends the device to the locked state (with the screensaver image) after a period of inactivity. It is usually small by default and with the official UI can be changed up to 1 hour. The lazy reading I described before is about leaving the reader with the current page shown and turning attention to something else until the you're ready to return to reading. If this period is long (you went for a couple of hours to prepare dinner), then the Screen Off time might fire before you return to reading so it's a good idea to increase it. To exceed 1 hour limit you should use other tools, for example to change it with adb you should use `adb shell settings put system screen_off_timeout 3600000`. This line correspondes to the mentioned 1 hour so you have to increase 3600000 accordingly

How to check that the script is working. The steps below are alternatives, but checking more than one will give more confindence
* Turn on Wi-fi indicator for the bottom status bar (it's better to use Letter kind since the icons of the Nook might look too small). Enabled Wi-Fi before you start KOReader with the patch. Turn pages several times ensuring a sufficient delay between them (at least 10 seconds). The Wi-Fi should turn to off. More information about Deep Sleep and Wi-Fi is below in the 'Limitations' section.
* Enable the clock in the status bar. Start the program, turn a couple of pages. Notice the time. Return after five or ten minutes. If the Deep Sleep is working, the time should freeze and show the one a the start of this test.   
* Turn on the percentage indicator for battery in status bar in KOReader (bottom or alt). Start KOReader (a fresh start or you can list a couple of pages if it's already in the memory), notice the percentage in the status bar. Leave the device for half an hour unattended (don't forget to make sure that the Screen Off time out is more that half an hour). After this period the percentage should stay the same. After going to the next page the percentage will either stay the same or change to the next value (92%->91%). If the script is not working, half an hour of unattended device will lead to 5-7% battery drain.
* Install Better Battery Stats. In it click Set Custom Ref in the menu. Return to the reader, leave it for some time or lazily page a couple of pages (make sure that the delay at least 10 seconds). Return to BBS, in bottom drop-downl list choose "Custom"  (The top list probably shows Summary). You should see Deep Sleep item with a non-empty percentage and time should raffly correspond to the deep sleep time of your test. If the script is not working, there will be no Deep Sleep section in the list
* Usually the device is capable of waking up quickly, but after some time you may notice that there's a little delay between you tap or press a button and the image of a new page showing. This indicator is not for initial checking, but you may getting used to it and probably even so that if something goes wrong, an unusual small increase in page appeareance might alert you  

For temporary disabling the patch you may use the patch management available in the KOReader menu. Basically this system just renames the pathches so they become incompatible with correct naming.

# Known limitations/sideeffects
* The patch should work with frontlight on. The device is still goes to Deep Sleep, while draining some energy for ligting. But it looks like Nook Glowlight 4 has a bug so take this into account. If you use the Home button long press to toggle the lighting, right after the action the internal DS system breaks, so device doesn't go to DS after this at all. The solutions that are possible are either briefly send it to the lock state and back (say, for 5 seconds) or to use the UI element for switching the lighting. I'm almost sure this is a bug, because even bn.ereader app is affected so can't send the device to DS after the Home button switching  
* This patch as of this writing was tested on KOReader versions 2023-10, 2023-08 and probably should be compatible with future versions until some serious refactoring in the code takes place.  
* Wi-Fi is not compatible with Deep Sleep so it is being switched off during system actions. But somehow the system knows that it was disabled indirectly and may return it to the enabled state in an unexpected moment. If you plan to have full control about Wi-Fi, disable it manually before reading. As long as I understood investigating bn.ereader app, the default software stack tries to minimize negative impact of these actions and might behave more predictibally than this patch.  
* If you're used to clock in the status bar of KOReader, have in mind that it will show the correct time only when a new page appeared. You can rely on being more or less correct if your tempo of listing is high, but if there are long pauses between the turns, the inicator might be misleading because the device is completely frozen between page turns. Don't forget that this misbehaviar is the result of this patch activity so don't report as an issue to the KOReader developers :)
* With the patch enabled and heavy image-based pdfs the program might feel more unresponive than before to the point of no reaction on taps or button presses. My guess is sometimes KOReader needs more CPU time for background tasks and this "go to sleep" mechanics basically interrupts this process. In this case, let it be in this state for some time and later it should behave better.
* For pdfs, djvu files the hardware buttons may sometimes turn more that one page at once. I don't exactly understand the reason, probably the system algorithm for detecting long presses (in order to send "repeat" messages) makes wrong calculation during a semi-sleeping phaze. But it's just my speculation. If you find this appear too often for you, use taps instead of hardware buttons for this partcular book.
* As I already mentioned, not all events inside KOReader are followed by going to DS. When you choosing a new book or changing the program feature with menu, this is going with the CPU fully working and leaving the device in this state will drain the battery as usual. So if you're really going to get used to the device being almost always asleep, don't forget to turn pages :)

# miscellaneous
* The patch uses logging made with the KOReader framework's logger object. All message go to the usual logcat list and are prefixed with `KRP:` string so to monitor the message remotely or post-action you may use `logcat | grep KRP:` command 
