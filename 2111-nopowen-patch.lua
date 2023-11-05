--[[
   nopowen v20231105
   This KOReader script allows sending Nook Glowlight 4/4e into Deep Sleep mode after every page turn.
   It allows to significally increase the reading time per single charge, because the device basically goes
   into minimum energy consumption between pages while preserving the screen image
--]]

--[[ ***********
  Set ActualSleep to false in order for emulate everying except actual going to sleep
  This allows the device to be connected and alive (for example for diagnosing/grepping logcat remotely)
--]] 
local ActualSleep = true

--[[ ***********
   1 seconds here before going to Deep Sleep is the value 'just in case'. It can be lower or bigger.
   Lower value like 0.5 might save additional energy page page turn
--]] 
local DS_DELAY_PAGES = 1

--[[ *********** 
   This delay for going to DS after opening a book. It is bigger than DS_DELAY_PAGES just in case
--]] 
local DS_DELAY_INTERCEPT = 4

--[[
   When trying to set the Android system setting this setting will allow showing the error message in the reader UI.
   If set to false only log will contain the message
--]]
local SCHEDULED_SET_ALLOWED_UI_MESSAGE = true




local logger = require("logger")

local android = require("android")

local ffi = require("ffi")

local function loclog(msg)
  if logger ~= nil then
    -- comment the line below to switch off all local logging
    logger.info('KRP: '..msg)
  end
end

function JniExceptCheck(jni)
   loclog('JniExceptCheck')
   if jni.env[0].ExceptionCheck(jni.env) == ffi.C.JNI_TRUE then 
     loclog('JniExceptCheck: Java exception occured')
     jni.env[0].ExceptionDescribe(jni.env)
     loclog('JniExceptCheck: describe. See the logcat for description of the issue')
     jni.env[0].ExceptionClear(jni.env)
     loclog('JniExceptCheck: after clear')
     return true
   else
     loclog('JniExceptCheck: No Java exception occured')
     return false
   end  
end

--[[ *********** 
  Two function below are reimplemented version of the corresponding ones from android.lua module:
    - CallStaticBooleanMethod
    - CallStaticIntMethod
  They allows catching Java exceptions for the main get/set calls in order to avoid crashing if Android doesn't allow 
  changing or getting the values.
--]]

function JniChecked_CallStaticBooleanMethod(jni, class, method, signature, ...)
    local clazz = jni.env[0].FindClass(jni.env, class)
    local methodID = jni.env[0].GetStaticMethodID(jni.env, clazz, method, signature)
    local res = jni.env[0].CallStaticBooleanMethod(jni.env, clazz, methodID, ...)

    local ExceptionOccured = JniExceptCheck(jni)

    jni.env[0].DeleteLocalRef(jni.env, clazz)

    if ExceptionOccured then
      res = false
    end  
    return res, ExceptionOccured
end

function JniChecked_CallStaticIntMethod(jni, class, method, signature, ...)
    local clazz = jni.env[0].FindClass(jni.env, class)
    local methodID = jni.env[0].GetStaticMethodID(jni.env, clazz, method, signature)
    local res = jni.env[0].CallStaticIntMethod(jni.env, clazz, methodID, ...)

    local ExceptionOccured = JniExceptCheck(jni)

    jni.env[0].DeleteLocalRef(jni.env, clazz)
    
    return res, ExceptionOccured
end

--[[ 
  the function android_settings_system_set_int is full equivalent of the method, 
  https://developer.android.com/reference/android/provider/Settings.Secure#putInt(android.content.ContentResolver,%20java.lang.String,%20int)    
  but made with ffi/jni technique
  You can use it for example for changing screen off time out ( android_settings_system_set_int("screen_off_timeout", 13300000) )
--]]

local android_settings_system_set_int = function(setting_name, value)
  if android ~= nil then
    if android.jni ~= nil then
      if android.app ~= nil then
        return 
          android.jni:context(android.app.activity.vm, function(jni)
            loclog('changing system setting ['..setting_name..'] to ['..value..']');   
            local arg_object = jni:callObjectMethod(
              android.app.activity.clazz,
              "getContentResolver",
              "()Landroid/content/ContentResolver;"
            )

            local arg_name = jni.env[0].NewStringUTF(jni.env, setting_name)
            local arg_value = ffi.cast("int32_t", value)
      
            local 
               ACallRes, ExceptionOccured = JniChecked_CallStaticBooleanMethod(jni,               
                --ACallRes = jni:callStaticBooleanMethod(
                    "android/provider/Settings$System",
                    "putInt",
                    "(Landroid/content/ContentResolver;Ljava/lang/String;I)Z",
                    arg_object,
                    arg_name,
                    arg_value
                )
                
            return ACallRes, ExceptionOccured    
          end)
      end
    end;  
  end  
end

local android_settings_system_get_int = function(setting_name, defvalue)
  if android ~= nil then
    if android.jni ~= nil then
      if android.app ~= nil then
        return android.jni:context(android.app.activity.vm, function(jni)
          loclog('getting system setting ['..setting_name..'] with defvalue ['..defvalue..']');   
          local arg_object = jni:callObjectMethod(
            android.app.activity.clazz,
            "getContentResolver",
            "()Landroid/content/ContentResolver;"
          )

          local arg_name = jni.env[0].NewStringUTF(jni.env, setting_name)
          local arg_defvalue = ffi.cast("int32_t", defvalue)
          
          local 
            retValue, ExceptionOccured = JniChecked_CallStaticIntMethod(jni,
            --retValue = jni:callStaticIntMethod(
                  "android/provider/Settings$System",
                  "getInt",
                  "(Landroid/content/ContentResolver;Ljava/lang/String;I)I",
                  arg_object,
                  arg_name,
                  arg_defvalue
              )
              
          if ExceptionOccured then   
            retValue = defvalue
          end  
              
          loclog('getting system setting returned:'..retValue)

          return retValue, ExceptionOccured    
        end)
      end
    end;  
  end  
end


--[[
  power_enhance_enable_set 
  the setting "power_enhance_enable" is the main driver of sending the Nook Glowlight 4 
  (and probably other ntx/android-based devices) to Deep Sleep without locking the device and redrawing the screen.
  The method involves the setting of the android setting power_enhance_enable (0) followed by setting it to (1)
--]]

local UIManager = require("ui/uimanager")

local UIManager_show_original = UIManager.show

local InfoMessage = require("ui/widget/infomessage")


--[[
local power_enhance_enable_set = function(value, allow_ui_error_message)
  local ok, additional = false, ''
   
  if ActualSleep then
    ok, additional = pcall(android_settings_system_set_int, "power_enhance_enable", value)
  else
     -- setting ok to false and ActualSleep to fales will allow seeing how failed message is presented in case of error
    ok, additional = true, 'no message'
  end  
  
  if ok then
    loclog('settings set pcall returned ok') 
    return additional
  else  
    loclog('failed to set power_enhance_enable (err msg: '..additional..')')
    if allow_ui_error_message then 
       loclog('allow_ui_error_message true, trying to show UI message about this')
       ok, additional = pcall(UIManager_show_original, UIManager, 
         InfoMessage:new{text = "KRP: setting power_enhance_enable failed, make sure you set 'Modify system settings' to 'allowed'"})
       if not ok then
         loclog('failed to UI show message with err: '..additional)
       end       
    end   
  end  
end

--]]

local power_enhance_enable_set = function(value, allow_ui_error_message)
  local ok, additional = false, ''
   
  if ActualSleep then
    ok = android_settings_system_set_int("power_enhance_enable", value)
  else
     -- setting ok to false and ActualSleep to fales will allow seeing how failed message is presented in case of error
    ok = true
  end  
  
  if ok then
    loclog('settings set returned ok') 
    return true
  else  
    loclog('failed to set power_enhance_enable (maybe exception, see the logcat for description)')
    if allow_ui_error_message then 
       loclog('allow_ui_error_message true, trying to show UI message about this')
       ok, additional = pcall(UIManager_show_original, UIManager, 
         InfoMessage:new{text = "KRP: setting power_enhance_enable failed, make sure you set 'Modify system settings' to 'allowed'"})
       if not ok then
         loclog('failed to UI show message with err: '..additional)
       end       
    end   
    
    return false
  end  
end


        
---------------------------------------        

--[[
 uncomment the "require" below if you have plans for 'pausing' technique involving 
 linear following with different sleeping calls  (i.e 100ms: ffiUtil.usleep(100000) )
 For the moment, the scheduled method works the best 

local ffiUtil = require("ffi/util")

--]] 




local function deepsleep_reset(allow_ui_error_message)
  loclog('reseting deepsleep (setting power_enhance_enable to 0)')
  
  power_enhance_enable_set(0, allow_ui_error_message)
end

local function delayed_deepsleep(allow_ui_error_message)
  -- UIManager:unschedule(delayed_deepsleep) 
  loclog('scheduled event. Setting power_enhance_enable to 1 (going to deep sleep)')
  
  power_enhance_enable_set(1, allow_ui_error_message)
end

local function deepsleep_schedule(seconds)
  -- switch off the previous sheduler. This couple of lines allows rapid paging without unpredicted calls. 
  -- In this case only the last one, long enough to survive would lead to Deep Sleep 
  UIManager:unschedule(delayed_deepsleep)
  
  loclog('scheduling DS for seconds: '..seconds)
  UIManager:scheduleIn(seconds, delayed_deepsleep, SCHEDULED_SET_ALLOWED_UI_MESSAGE)  
end

local function InterceptReaderWidget(Widget)

  -- trying to find two known modules for two class of file formats (rolling/paging)
  
  local pageHandler = Widget.paging
    if pageHandler == nil then
      loclog('no paging found, trying rolling')
      pageHandler = Widget.rolling
      if pageHandler ~= nil then
        loclog('rolling found!')   
      end
    else
      loclog('paging found!')
  end

  if pageHandler ~= nil then
    loclog('intercepting onGotoViewRel method of the found pageHandler')
    local pageHandler_onGotoViewRel_original = pageHandler.onGotoViewRel
    
    -- luckily both modules has the same method for showing new page with relative offset: onGotoViewRel(diff)
    -- this will be the primary receiver of page turning "events". 
    
    pageHandler.onGotoViewRel = function(self, diff)

      loclog('i_am_paging!');
      
      -- Resetting power enhancer 
      deepsleep_reset(false)
      
      loclog('after power_enhance_enable_set(0)');
      pageHandler_onGotoViewRel_original(self, diff)
      loclog('after orignal GotoViewRel');
      loclog('scheduling deep sleep after page turn')
      
      local front_light_on = android_settings_system_get_int('front_light_mode', -1)
      
      loclog('current front_light_mode: '..front_light_on)
      
      deepsleep_schedule(DS_DELAY_PAGES)
    end
    
    -- going to deep sleep after opening new book, starting the program and some other cases.
    -- here we give it more time just in case 
    
    loclog('scheduling deep sleep after successfull widget intercept')
    deepsleep_reset(false)    
    deepsleep_schedule(DS_DELAY_INTERCEPT)
  else
    loclog('no paging or rolling found') 
  end
end

--[[
  the function below hooks to UIManager in order to monitor any showing widget. When the ReaderUI widget is shown, 
  it tries to hook to one of known modules to intercept page turns
--]] 

UIManager.show = function(self, widget, refreshtype, refreshregion, x, y, refreshdither)
   local title = widget.id or widget.name or tostring(widget)

   loclog('UI widget showing: '..title)
   local originalShowRes = UIManager_show_original(self, widget, refreshtype, refreshregion, x, y, refreshdither)
   
   if title == 'ReaderUI' then
     loclog('Title match for ReaderUI, trying to intercept')
     InterceptReaderWidget(widget)
   else  
     loclog('Unrecognized widget, ignoring')
   end   
   
   return originalShowRes  
 end
  
