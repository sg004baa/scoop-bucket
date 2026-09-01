[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $TargetPath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $ShortcutPath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $Aumid,

    [Parameter()]
    [string] $IconPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$target = [System.IO.Path]::GetFullPath($TargetPath)
if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
    throw "Shortcut target does not exist: $target"
}

$shortcut = [System.IO.Path]::GetFullPath($ShortcutPath)
$shortcutDirectory = [System.IO.Path]::GetDirectoryName($shortcut)
if ([string]::IsNullOrWhiteSpace($shortcutDirectory)) {
    throw "Shortcut path has no parent directory: $shortcut"
}
[System.IO.Directory]::CreateDirectory($shortcutDirectory) | Out-Null

$icon = if ([string]::IsNullOrWhiteSpace($IconPath)) {
    $target
} else {
    [System.IO.Path]::GetFullPath($IconPath)
}
if (-not (Test-Path -LiteralPath $icon -PathType Leaf)) {
    throw "Shortcut icon does not exist: $icon"
}

if (-not ('WezTermScoop.ShortcutWriter' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

namespace WezTermScoop
{
    [StructLayout(LayoutKind.Sequential)]
    internal struct PROPERTYKEY
    {
        internal Guid formatId;
        internal uint propertyId;

        internal PROPERTYKEY(Guid formatId, uint propertyId)
        {
            this.formatId = formatId;
            this.propertyId = propertyId;
        }
    }

    [StructLayout(LayoutKind.Explicit, Size = 24)]
    internal struct PROPVARIANT
    {
        [FieldOffset(0)]
        internal ushort valueType;

        [FieldOffset(2)]
        internal ushort reserved1;

        [FieldOffset(4)]
        internal ushort reserved2;

        [FieldOffset(6)]
        internal ushort reserved3;

        [FieldOffset(8)]
        internal IntPtr pointerValue;

        internal static PROPVARIANT FromString(string value)
        {
            PROPVARIANT variant = new PROPVARIANT();
            variant.valueType = 31; // VT_LPWSTR
            variant.pointerValue = Marshal.StringToCoTaskMemUni(value);
            return variant;
        }
    }

    [ComImport]
    [Guid("00021401-0000-0000-C000-000000000046")]
    [ClassInterface(ClassInterfaceType.None)]
    internal class ShellLink
    {
    }

    [ComImport]
    [Guid("000214F9-0000-0000-C000-000000000046")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IShellLinkW
    {
        [PreserveSig]
        int GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder file, int maximumPath, IntPtr findData, uint flags);

        [PreserveSig]
        int GetIDList(out IntPtr itemIdList);

        [PreserveSig]
        int SetIDList(IntPtr itemIdList);

        [PreserveSig]
        int GetDescription([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder description, int maximumName);

        [PreserveSig]
        int SetDescription([MarshalAs(UnmanagedType.LPWStr)] string description);

        [PreserveSig]
        int GetWorkingDirectory([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder directory, int maximumPath);

        [PreserveSig]
        int SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string directory);

        [PreserveSig]
        int GetArguments([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder arguments, int maximumPath);

        [PreserveSig]
        int SetArguments([MarshalAs(UnmanagedType.LPWStr)] string arguments);

        [PreserveSig]
        int GetHotkey(out short hotkey);

        [PreserveSig]
        int SetHotkey(short hotkey);

        [PreserveSig]
        int GetShowCmd(out int showCommand);

        [PreserveSig]
        int SetShowCmd(int showCommand);

        [PreserveSig]
        int GetIconLocation([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder iconPath, int iconPathLength, out int iconIndex);

        [PreserveSig]
        int SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string iconPath, int iconIndex);

        [PreserveSig]
        int SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string relativePath, uint reserved);

        [PreserveSig]
        int Resolve(IntPtr windowHandle, uint flags);

        [PreserveSig]
        int SetPath([MarshalAs(UnmanagedType.LPWStr)] string file);
    }

    [ComImport]
    [Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IPropertyStore
    {
        [PreserveSig]
        int GetCount(out uint propertyCount);

        [PreserveSig]
        int GetAt(uint propertyIndex, out PROPERTYKEY key);

        [PreserveSig]
        int GetValue(ref PROPERTYKEY key, out PROPVARIANT value);

        [PreserveSig]
        int SetValue(ref PROPERTYKEY key, ref PROPVARIANT value);

        [PreserveSig]
        int Commit();
    }

    [ComImport]
    [Guid("0000010B-0000-0000-C000-000000000046")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    internal interface IPersistFile
    {
        [PreserveSig]
        int GetClassID(out Guid classId);

        [PreserveSig]
        int IsDirty();

        [PreserveSig]
        int Load([MarshalAs(UnmanagedType.LPWStr)] string fileName, uint mode);

        [PreserveSig]
        int Save([MarshalAs(UnmanagedType.LPWStr)] string fileName, [MarshalAs(UnmanagedType.Bool)] bool remember);

        [PreserveSig]
        int SaveCompleted([MarshalAs(UnmanagedType.LPWStr)] string fileName);

        [PreserveSig]
        int GetCurFile([MarshalAs(UnmanagedType.LPWStr)] out string fileName);
    }

    internal static class NativeMethods
    {
        [DllImport("ole32.dll")]
        internal static extern int PropVariantClear(ref PROPVARIANT variant);
    }

    public static class ShortcutWriter
    {
        private static readonly PROPERTYKEY AppUserModelIdKey = new PROPERTYKEY(
            new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"),
            5);

        public static void Create(string targetPath, string shortcutPath, string appUserModelId, string iconPath)
        {
            ShellLink shellObject = null;
            try
            {
                shellObject = new ShellLink();
                IShellLinkW shellLink = (IShellLinkW)shellObject;
                IPropertyStore propertyStore = (IPropertyStore)shellObject;
                IPersistFile persistFile = (IPersistFile)shellObject;

                ThrowIfFailed(shellLink.SetPath(targetPath));
                ThrowIfFailed(shellLink.SetWorkingDirectory(Path.GetDirectoryName(targetPath)));
                ThrowIfFailed(shellLink.SetIconLocation(iconPath, 0));

                PROPERTYKEY key = AppUserModelIdKey;
                PROPVARIANT value = PROPVARIANT.FromString(appUserModelId);
                try
                {
                    ThrowIfFailed(propertyStore.SetValue(ref key, ref value));
                }
                finally
                {
                    ThrowIfFailed(NativeMethods.PropVariantClear(ref value));
                }

                ThrowIfFailed(propertyStore.Commit());
                ThrowIfFailed(persistFile.Save(shortcutPath, true));
            }
            finally
            {
                if (shellObject != null && Marshal.IsComObject(shellObject))
                {
                    Marshal.FinalReleaseComObject(shellObject);
                }
            }
        }

        private static void ThrowIfFailed(int result)
        {
            Marshal.ThrowExceptionForHR(result);
        }
    }
}
'@
}

[WezTermScoop.ShortcutWriter]::Create($target, $shortcut, $Aumid, $icon)
