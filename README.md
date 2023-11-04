# What is it
The single file here is an energy saving patch for Android version of KOReader app, working on Nook Glowlight 4/4e and probably some other models of eInk readers.

# Background
The screen and CPU is the most power hungry parts of a conventional smartphone. Android and other mobile systems take special care to minimize this. One of possible low-consumptions states is Deep Sleep (aka Doze) mode when the screen is off and CPU basically switches off only to be lightly alert about some of events that might occur. Touching the screen or pressing the hardware buttons are the examples of such events. Most of modern smartphones use this mode, but for them having LCD screens, the mode is possible only when the screen is off.

But eInk devices has a different kind of screen that allows keeping the current image without need for the energy maintaining it. Together with Deep Sleep mode this allows a unique mode of usage when for a short period of time both the screen and CPU is fully working preparing and showing a page and then screen just doesn't consume energy naturally while CPU goes into the Deep Sleep mode. The latter period is obvisouly longer that the former so overall this strategy would theoretically allow saving much energy when reading a e-Book.   

 
