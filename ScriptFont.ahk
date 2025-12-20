#Requires AutoHotkey v1.1.36+
#Include %A_ScriptDir%
#Include .\lib\FontResource.ahk
;  #Include .\lib\GdipInit.ahk
#Include .\lib\GdipPrivateFont.ahk
#Include .\lib\getFullPathName.ahk
#Include .\lib\getScriptGuiClassName.ahk
;==============================================================
; ScriptFont — Runtime font loader & GDI+ private font manager
;
; GitHub: https://github.com/SevenKeyboard/script-font
; Author: SevenKeyboard Ltd. (2025)
; License: MIT License
;==============================================================

/*
Example Usage:
    if (!ScriptFont.isAdded(filename,"Private"))
        ScriptFont.add(filename,"Private")
*/

class VersionManager_ScriptFont
{
    static _ := VersionManager_ScriptFont._init()
    _init()    {
        global
        SCRIPTFONT_VERSION := "1.1.1"
        if (!this._verCheck(FONTRESOURCE_VERSION, "1.0.0"))
            throw exception("FontResource version 1.x is required (minimum 1.0.0).")
        /*
        if (!this._verCheck(GDIPINIT_VERSION, "1.0.0"))
            throw exception("GdipInit version 1.x is required (minimum 1.0.0).")
        */
        if (!this._verCheck(GDIPPRIVATEFONT_VERSION, "1.0.0"))
            throw exception("GdipPrivateFont version 1.x is required (minimum 1.0.0).")
        if (!this._verCheck(GETSCRIPTGUICLASSNAME_VERSION, "1.0.0"))
            throw exception("getScriptGuiClassName version 1.x is required (minimum 1.0.0).")
        return true
    }
    _verCheck(byRef actual, required)    {
        if !isSet(actual)
            return false
        actualMajor     := strSplit(actual, ".",, 2)[1]
        requiredMajor   := strSplit(required, ".",, 2)[1]
        if (actualMajor !== requiredMajor)
            return false
        return verCompare(actual, ">=" required)
    }
}
class ScriptFont
{
    static _:=ScriptFont._init()
    _init()    {
        onExit(objBindMethod(this,"_onApplicationExit"))
        this._fonts:={norm:{}, notEnum:{}, private:{}}
        this._onExitFonts:={norm:{}, notEnum:{}}       
    }
    ;-------------------------------
    add(filename, option:="Private", force:=false, removeOnExit:=true)    {
        /*
        filename
            "...\fonts\Noto_Sans_KR\NotoSansKR-Regular.otf"
        option
            "Norm"
            "NotEnum"
            "Private" (Default)        
        force
            true
            false (Default)
        removeOnExit
            true (Default)
            false
        */
        filename:=getFullPathName(fileName)
        i:=0
        this._setParams(option, fl, type)
        fontAdded:=this.isAdded(filename)
        if (!fontAdded || force)    {
            if (i:=FontResource.addEx(filename, fl))    {
                switch (fontAdded)
                {
                    case true:      this._fonts[type][filename]++
                    default:        this._fonts[type][filename]:=1
                }
                if (removeOnExit && this._onExitFonts.hasKey(type))    {
                    if (!this._onExitFonts[type].hasKey(filename))
                        this._onExitFonts[type][filename]:=0
                    this._onExitFonts[type][filename]++
                }
            }
        }
        return i
    }
    remove(filename, option:="Private", tryCount:=0)    {
        filename:=getFullPathName(fileName)
        this._setParams(option, fl, type)
        switch (tryCount)
        {
            case -1:
                while (FontResource.removeEx(filename,fl))    {
                }
                if (this._fonts[type].hasKey(filename))
                    this._fonts[type].delete(filename)
                if (this._onExitFonts.hasKey(type) && this._onExitFonts[type].hasKey(filename))
                    this._onExitFonts[type].delete(filename)
            case 0:            
                if (!this._fonts[type].hasKey(filename))
                    return
                loop % this._fonts[type][filename]    {
                }  until (!FontResource.removeEx(filename,fl))
                this._fonts[type].delete(filename)
                if (this._onExitFonts.hasKey(type) && this._onExitFonts[type].hasKey(filename))
                    this._onExitFonts[type].delete(filename)
            default: ;  \d+
                if (!this._fonts[type].hasKey(filename))
                    return
                i:=0
                loop % this._fonts[type][filename]    {
                    if (tryCount<A_Index)
                        break
                    if (FontResource.removeEx(filename,fl))    {
                        i++
                    }  else  {
                        break
                    }
                }
                this._fonts[type][filename]-=i
                if (this._fonts[type][filename]<=0)
                    this._fonts[type].delete(filename)
                if (this._onExitFonts.hasKey(type) && this._onExitFonts[type].hasKey(filename))    {
                    this._onExitFonts[type][filename]-=i
                    if (this._onExitFonts[type][filename]<=0)
                        this._onExitFonts[type].delete(filename)
                }
        }
    }
    removeAll()    {
        for type,obj in this._fonts    {
            fl:=this._flagFromType(type)
            for filename,count in obj    {
                loop % count    {
                } until (!FontResource.removeEx(filename,fl))
            }
        }
        this._fonts:={norm:{}, notEnum:{}, private:{}}
        this._onExitFonts:={norm:{}, notEnum:{}}
    }
    isAdded(filename, option:="Private")    {
        filename:=getFullPathName(fileName)
        this._setParams(option,,type)
        return this._fonts[type].hasKey(filename)
            ?this._fonts[type][filename]
            :0
    }
    class Gdip
    {
        fileAdd(filename, gdipPrivateFontID:="Default")    {
            filename:=getFullPathName(fileName)
            ID:=gdipPrivateFontID
            if (ID=="")
                return
            if (!this.hasKey(ID))
                this[ID]:={}, this[ID]._GpPrivateFont:=new GdipPrivateFont
            return this[ID]._GpPrivateFont.fileAdd(filename)
        }
        familyCreate(name, gdipPrivateFontID:="Default")    {
            ID:=gdipPrivateFontID
            return (this.hasKey(ID))
                ?this[ID]._GpPrivateFont.familyCreate(name)
                :0
        }
        familyDelete(name, gdipPrivateFontID:="Default")    {
            ID:=gdipPrivateFontID
            if (this.hasKey(ID))
                this[ID]._GpPrivateFont.familyDelete(name)
        }
    }
    ;-------------------------------
    _setParams(option, byRef fl:="", byRef type:="")    {
        switch (option)
        {
            default:                fl:=0                           ,type:="norm"
            case "Private":         fl:=FontResource.FR_PRIVATE     ,type:="private"
            case "NotEnum":         fl:=FontResource.FR_NOT_ENUM    ,type:="notEnum"
        }
    }
    _flagFromType(type)    {
        switch (type)
        {
            case "norm":            return 0
            case "private":         return FontResource.FR_PRIVATE
            case "notEnum":         return FontResource.FR_NOT_ENUM
        }
    }
    ;-------------------------------
    _onApplicationExit(exitReason, exitCode)    {
        menu Tray, NoIcon
        if (pid:=dllCall("Kernel32.dll\GetCurrentProcessId", "UInt"))    {
            detectHiddenWindows % format("{2}",prevDHW:=A_DetectHiddenWindows,"Off")
            winGet id, list, % "ahk_class " getScriptGuiClassName() " ahk_pid " pid
            loop % id
                winHide % "ahk_id " id%A_Index%
            detectHiddenWindows % prevDHW
        }
        for type,obj in this._onExitFonts    { ;  It seems to be taking longer than expected...
            fl:=this._flagFromType(type)
            for filename,count in obj    {
                ;  outputDebug % fl "`t" filename "`t" count
                loop % count    {
                } until (!FontResource.removeEx(filename,fl))
            }
        }
    }
}