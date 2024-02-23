---@meta
---@diagnostic disable: lowercase-global, missing-return, duplicate-doc-alias, missing-fields

---Because all strings pass through Java at some point it can be useful to handle them with Unicode support (since Java's internal string representation is UTF-8 encoded). In particular, screens display UTF-8 strings, meaning the related GPU functions expect UTF-8 strings. Also, keyboard input will generally be UTF-8 encoded, especially the clipboard.
---***
---However, keep in mind that while wide characters can be displayed, input and output of those is not fully supported in OpenOS's software (i.e. the shell, edit and Lua interpreter).
-- -@type UnicodeAPI
unicode = {}
---This API mainly provides information about the computer a Lua state is running on, such as its address and uptime. It also contains functions for user management. This could belong to the os table, but in order to keep that “clean” it's in its own API.
---@type ComputerAPI
computer = {}
---The component API is used to access and interact with components available to a computer. Also see the page on component interaction.
---@type ComponentAPI
component = {}

--- A table that can be iterated over without calling ipairs
---@alias iterableList table
---@alias componentType "screen" | "gpu" | "computer" | "robot" | "eeprom" | "modem" | "filesystem" | "data"
---@alias proxy ScreenProxy | GPUProxy | ComputerProxy | RobotProxy | EEPROMProxy | ModemProxy | FilesystemProxy | DataProxy
--- An ID (address) of a component
---@alias ID string
--- Anything that can be converted to a string
---@alias Serializable number | string | nil | boolean | { [Serializable]: Serializable }
--- ANything that can by sent on the network
---@alias Sendable number | string | nil | boolean
--- A hex (`0xRRGGBB`) code color
---@alias color integer
--- A color depth
---@alias colorDepth 1 | 2 | 4
--- A color depth as a string
---@alias colorDepthString "OneBit" | "FourBit" | "EightBit"
--- A filesystem handle mode.
---@alias FSHandleMode "r" | "rb" | "w" | "wb" | "a" | "ab"
--- A filesystem handle ID
---@alias FSHandle integer
--- A Lua Architecture
---@alias Architecture "Lua 5.2" | "Lua 5.3"
--- An integer port between 1 and 65536
---@alias Port integer
--- A DataCard(T3) encryption key
---@class EncryptionKey
---  @field isPublic fun(): boolean ---Returns whether key is public.
---  @field keyType fun(): "ec-private" | "ec-public" ---Returns type of key.
---  @field serialize fun():string ---Returns the string representation of key. Result is binary data.
---  @field type "userdata"
---@class PrivateKey : EncryptionKey
---  @field isPublic fun(): false
---  @field keyType fun(): "ec-private" 
---@class PublicKey : EncryptionKey
---  @field isPublic fun(): true ---Returns whether key is public.
---  @field keyType fun(): "ec-public" ---Returns type of key.
---@class Proxy
---  @field address ID
---  @field type componentType
--- The argument for data(t3).generateKeyPair
---@alias BitLength 256|384
-- Overloads are shown in the description and deprecated functions aren't shown.

---A list of methods that component.proxy returns when the component whose ID passed in is a Screen.
---@class ScreenProxy : Proxy
--- @field type "screen"
---  @field isOn                 fun()                                                                                                              : boolean                                        Returns whether the screen is currently on.
---  @field turnOn               fun()                                                                                                              : boolean                                        Turns the screen on. Returns true if it was off.
---  @field turnOff              fun()                                                                                                              : boolean                                        Turns off the screen. Returns true if it was on.
---  @field getAspectRatio       fun()                                                                                                              : number,number                                  The aspect ratio of the screen. For multi-block screens this is the number of blocks, horizontal and vertical.
---  @field getKeyboards         fun()                                                                                                              : ID[]                                           The list of keyboards attached to the screen.
---  @field setPrecise           fun(enabled:boolean)                                                                                               : boolean                                        Set whether to use high-precision mode (sub-pixel mouse event position). Requires Screen (Tier 3).
---  @field isPrecise            fun()                                                                                                              : boolean                                        Check whether high-precision mode is enabled (sub-pixel mouse event position). Requires Screen (Tier 3).
---  @field setTouchModeInverted fun(enabled:boolean)                                                                                               : boolean                                        Sets Inverted Touch mode (Sneak-activate opens GUI if set to true).
---  @field isTouchModeInverted  fun()                                                                                                              : boolean                                        Check to see if Inverted Touch mode is enabled (Sneak-activate opens GUI is set to true).

---A list of methods that component.proxy returns when the component whose ID passed in is a GPU.
---@class GPUProxy : Proxy
--- @field type "gpu"
---  @field bind                 fun(address: ID, reset?:boolean)                                                                                                                                    Tries to bind the GPU to a screen with the specified address. Returns `true` on success, `false` and an error message on failure. Resets the screen's settings if reset is 'true'. A GPU can only be bound to one screen at a time. All operations on it will work on the bound screen. If you wish to control multiple screens at once, you'll need to put more than one graphics card into your computer.
---  @field getScreen            fun()                                                                                                              : ID                                             Get the address of the screen the GPU is bound to. Since 1.3.2.
---  @field getBackground        fun()                                                                                                              : color|integer,boolean                          Gets the current background color. This background color is applied to all “pixels” that get changed by other operations. Note that the returned number is either an RGB value in hexadecimal format, i.e. `0xRRGGBB`, or a palette index. The second returned value indicates which of the two it is (`true` for palette color, `false` for RGB value).
---  @field setBackground        fun(color:color, isPaletteIndex?:boolean)                                                                                                                           Sets the background color to apply to “pixels” modified by other operations from now on. The returned value is the old background color, as the actual value it was set to (i.e. not compressed to the color space currently set). The first value is the previous color as an RGB value. If the color was from the palette, the second value will be the index in the palette. Otherwise it will be `nil`. Note that the color is expected to be specified in hexadecimal RGB format, i.e. `0xRRGGBB`. This is to allow uniform color operations regardless of the color depth supported by the screen and GPU.
---  @field getForeground        fun()                                                                                                              : color|integer, boolean                         Like getBackground, but for the foreground color.
---  @field setForeground        fun(color:color|integer, isPaletteIndex?:boolean)                                                                                                                   Like setBackground, but for the foreground color.
---  @field getPaletteColor      fun(index:integer)                                                                                                 : color                                          Gets the RGB value of the color in the palette at the specified index.
---  @field setPaletteColor      fun(index:integer,value:color)                                                                                     : color                                          Sets the RGB value of the color in the palette at the specified index.
---  @field maxDepth             fun()                                                                                                              : colorDepth                                     Gets the maximum supported color depth supported by the GPU and the screen it is bound to (minimum of the two).
---  @field getDepth             fun()                                                                                                              : colorDepth                                     The currently set color depth of the GPU/screen, in bits. Can be 1, 4 or 8.
---  @field setDepth             fun(bit:colorDepth)                                                                                                : colorDepthString                               Sets the color depth to use. Can be up to the maximum supported color depth. If a larger or invalid value is provided it will throw an error. Returns the old depth as one of the strings `OneBit`, `FourBit`, or `EightBit`.
---  @field maxResolution        fun()                                                                                                              : number,number                                  Gets the maximum resolution supported by the GPU and the screen it is bound to (minimum of the two).
---  @field getResolution        fun()                                                                                                              : number,number                                  Gets the currently set resolution.
---  @field setResolution        fun(width:number,height:number)                                                                                    : boolean                                        Sets the specified resolution. Can be up to the maximum supported resolution. If a larger or invalid resolution is provided it will throw an error. Returns `true` if the resolution was changed (may return `false` if an attempt was made to set it to the same value it was set before), `false` otherwise.
---  @field getViewport          fun()                                                                                                              : number,number                                  Get the current viewport resolution.
---  @field setViewport          fun(width:number,height:number)                                                                                    : boolean                                        Set the current viewport resolution. Returns `true` if it was changed (may return `false` if an attempt was made to set it to the same value it was set before), `false` otherwise. This makes it look like screen resolution is lower, but the actual resolution stays the same. Characters outside top-left corner of specified size are just hidden, and are intended for rendering or storing things off-screen and copying them to the visible area when needed. Changing resolution will change viewport to whole screen.
---  @field get                  fun(x:integer,y:integer)                                                                                           : string, number, number, number|nil, number|nil Gets the character currently being displayed at the specified coordinates. The second and third returned values are the fore- and background color, as hexvalues. If the colors are from the palette, the fourth and fifth values specify the palette index of the color, otherwise they are nil.
---  @field set                  fun(x:number,y:number,value:string,vertical?:boolean)                                                              : boolean                                        Writes a string to the screen, starting at the specified coordinates. The string will be copied to the screen's buffer directly, in a single row. This means even if the specified string contains line breaks, these will just be printed as special characters, the string will not be displayed over multiple lines. Returns `true` if the string was set to the buffer, `false` otherwise. The optional fourth argument makes the specified text get printed vertically instead, if `true`.
---  @field copy                 fun(x:number,y:number,width:number,height:number,tx:number,ty:number)                                              : boolean                                        Copies a portion of the screens buffer to another location. The source rectangle is specified by the `x`, `y`, `width` and `height` parameters. The target rectangle is defined by `x + tx`, `y + ty`, `width` and `height`. Returns `true` on success, `false` otherwise.
---  @field fill                 fun(x:number,y:number,width:number,height:number,char:string)                                                      : boolean                                        Fills a rectangle in the screen buffer with the specified character. The target rectangle is specified by the `x` and `y` coordinates and the rectangle's `width` and `height`. The fill character `char` must be a string of length one, i.e. a single character. Returns `true` on success, `false` otherwise. Note that filling screens with spaces (` `) is usually less expensive, i.e. consumes less energy, because it is considered a “clear” operation (see config).
-- Buffers
---  @field getActiveBuffer      fun()                                                                                                              : integer                                        Returns the index of the currently selected buffer. 0 is reserved for the screen, and may return 0 even when there is no screen.
---  @field setActiveBuffer      fun(index:integer)                                                                                                 : integer                                        Sets the active buffer to `index`. 0 is reserved for the screen and can be set even when there is no screen. Returns nil for an invalid index (0 is valid even with no screen)
---  @field buffers              fun()                                                                                                              : table                                          Returns an array of all current page indexes (0 is not included in this list, that is reserved for the screen).
---  @field allocateBuffer       fun(width?:integer,height?:integer)                                                                                : integer                                        Allocates a new buffer with dimensions width*height (gpu max resolution by default). Returns the index of this new buffer or error when there is not enough video memory. A buffer can be allocated even when there is no screen bound to this gpu. Index 0 is always reserved for the screen and thus the lowest possible index of an allocated buffer is always 1.
---  @field freeBuffer           fun(index?:integer)                                                                                                : boolean                                        Removes buffer at `index` (default: current buffer index). Returns true if the buffer was removed. When you remove the currently selected buffer, the gpu automatically switches back to index 0 (reserved for a screen)
---  @field freeAllBuffers       fun()                                                                                                                                                               Removes all buffers, freeing all video memory. The buffer index is always 0 after this call.
---  @field totalMemory          fun()                                                                                                              : integer                                        Returns the total memory size of the gpu vram. This does not include the screen.
---  @field freeMemory           fun()                                                                                                              : integer                                        Returns the total free memory not allocated to buffers. This does not include the screen.
---  @field getBufferSize        fun(index?:integer)                                                                                                : integer,integer                                Returns the buffer size at `index` (default: current buffer index). Returns the screen resolution for index 0. Returns nil for invalid indexes
---  @field bitblt               fun(dst?:integer,col:integer,row:integer,width:integer,height:integer,src:integer,fromCol:integer,fromRow:integer)                                                  Copy a region from buffer to buffer, screen to buffer, or buffer to screen. `bitblt` should preform very fast on repeated use. If the buffer is dirty there is an initial higher cost to sync the buffer with the destination object. If you have a large number of updates to make with frequent bitblts, consider making multiple and smaller buffers. If you plan to use a static buffer (one with few or no updates), then a large buffer is just fine. Returns `true` on success.

---A list of methods that component.proxy returns when the component whose ID passed in is a Computer.
---@class ComputerProxy : Proxy
--- @field type "computer"
---  @field start                fun()                                                                                                              : boolean                                        Tries to start the computer. Returns `true` on success, `false` otherwise. Note that this will also return `false` if the computer was already running. If the computer is currently shutting down, this will cause the computer to reboot instead.
---  @field stop                 fun()                                                                                                              : boolean                                        Tries to stop the computer. Returns `true` on success, `false` otherwise. Also returns `false` if the computer is already stopped.
---  @field isRunning            fun()                                                                                                              : boolean                                        Returns whether the computer is currently running.
---  @field beep                 fun(frequency?:number,duration?:number)                                                                                                                             Plays a tone, useful to alert users via audible feedback. Supports frequencies from 20 to 2000Hz, with a duration of up to 5 seconds.
---  @field getDeviceInfo        fun()                                                                                                              : table                                          Returns a table of device information. Note that this is architecture-specific and some may not implement it at all.
---  @field crash                fun(reason:string)                                                                                                                                                  Attempts to crash the computer for the specified reason.
---  @field getArchitecture      fun()                                                                                                              : Architecture                                   Returns the computer's current architecture.
---  @field isRobot              fun()                                                                                                              : boolean                                        Returns whether or not the computer is, in fact, a robot.

---A list of methods that component.proxy returns when the component whose ID passed in is a Robot.
---@class RobotProxy : Proxy
--- @field type "robot"
---A list of methods that component.proxy returns when the component whose ID passed in is an EEPROM.
---@class EEPROMProxy : Proxy
--- @field type "eeprom"
---  @field get                  fun()                                                                                                              : string                                         Get the currently stored byte array.
---  @field set                  fun(data:string)                                                                                                                                                    Overwrite the currently stored byte array.
---  @field getLabel             fun()                                                                                                              : string                                         Get the label of the EEPROM.
---  @field setLabel             fun(data:string)                                                                                                                                                    Set the label of the EEPROM.
---  @field getSize              fun()                                                                                                              : integer                                        Gets the maximum storage capacity of the EEPROM.
---  @field getDataSize          fun()                                                                                                              : integer                                        Gets the maximum data storage capacity of the EEPROM.
---  @field getData              fun()                                                                                                              : string                                         Gets currently stored byte-array (usually the component address of the main boot device).
---  @field setData              fun(data:string)                                                                                                                                                    Overwrites currently stored byte-array with specified string.
---  @field getChecksum          fun()                                                                                                              : string                                         Gets Checksum of data on EEPROM.
---  @field makeReadonly         fun(checksum:string)                                                                                               : boolean                                        Makes the EEPROM Read-only if it isn't. This process cannot be reversed.

---A list of methods that component.proxy returns when the component whose ID passed in is a Modem.
---@class ModemProxy : Proxy
--- @field type "modem"
---  @field isWireless           fun()                                                                                                              : boolean                                        Returns whether this modem is capable of sending wireless messages.
---  @field maxPacketSize        fun()                                                                                                              : integer                                        Returns the maximum packet size for sending messages via network cards. Defaults to 8192. You can change this in the OpenComputers configuration file. Every value in a message adds two bytes of overhead. (Even if there's only one value.) `number`s add another 8 bytes, `true`/`false`/`nil` another 4 bytes, and `string`s exactly as many bytes as the string contains--though empty strings still count as one byte.
---  @field isOpen               fun(port:Port)                                                                                                     : boolean                                        Returns whether the specified “port” is currently being listened on. Messages only trigger signals when they arrive on a port that is open.
---  @field open                 fun(port:Port)                                                                                                     : boolean                                        Opens the specified port number for listening. Returns `true` if the port was opened, `false` if it was already open. Note: maximum port is 65535
---  @field close                fun(port?:Port)                                                                                                    : boolean                                        Closes the specified port (default: all ports). Returns true if ports were closed.
---  @field send                 fun(address:ID,port:Port,...:Sendable)                                                                             : boolean                                        Sends a network message to the specified address. Returns `true` if the message was sent. This does not mean the message was received, only that it was sent. No port-sniffing for you. Any additional arguments are passed along as data. These arguments must be basic types: `nil`, `boolean`, `number` and `string` values are supported, tables and functions are not. See the serialization API for serialization of tables. The number of additional arguments is limited. The default limit is 8. It can be changed in the OpenComputers configuration file, but this is not recommended; higher limits can allow relatively weak computers to break relatively strong ones with no defense possible, while lower limits will prevent some protocols from working.
---  @field broadcast            fun(port:ID,...:Sendable)                                                                                          : boolean                                        Sends a broadcast message. This message is delivered to all reachable network cards. Returns `true` if the message was sent. Note that broadcast messages are not delivered to the modem that sent the message. All additional arguments are passed along as data. See `send`.
---  @field getStrength          fun()                                                                                                              : number                                         The current signal strength to apply when sending messages. Wireless network cards only.
---  @field setStrength          fun(value:number)                                                                                                  : number                                         Sets the signal strength. If this is set to a value larger than zero, sending a message will also generate a wireless message. Also, calls to set the strength that exceed the installed modem's maximum strength will simply set the modem's strength to it's maximum. The higher the signal strength the more energy is required to send messages, though. *Wireless network cards only.*
---  @field getWakeMessage       fun()                                                                                                              : string                                         Gets the current wake-up message. When the network card detects the wake message (a string in the first argument of a network packet), on any port and the machine is off, the machine is started. Works for robots, cases, servers, drones, and tablets. Linked Cards provide this same functionality.
---  @field setWakeMessage       fun(message:string,fuzzy?:boolean)                                                                                 : string                                         Sets the wake-up message to the specified **string**. The message matching can be fuzzy (default is false). A fuzzy match ignores additional trailing arguments in the network packet.

---A list of methods that component.proxy returns when the component whose ID passed in is a Filesystem.
---@class FilesystemProxy : Proxy
--- @field type "filesystem"
---  @field spaceUsed            fun()                                                                                                              : integer                                       The currently used capacity of the file system, in bytes.
---  @field open                 fun(path:string,mode?:FSHandleMode)                                                                                 : FSHandle                                      Opens a new file descriptor and returns its handle.
---  @field seek                 fun(handle:number,whence:string,offset:number)                                                                     : number                                        Seeks in an open file descriptor with the specified handle. Returns the new pointer position.
---  @field makeDirectory        fun(path:string)                                                                                                   : boolean                                       Creates a directory at the specified absolute path in the file system. Creates parent directories, if necessary.
---  @field exists               fun(path:string)                                                                                                   : boolean                                       Returns whether an object exists at the specified absolute path in the file system.
---  @field isReadOnly           fun()                                                                                                              : boolean                                       Returns whether the file system is read-only.
---  @field write                fun(handle:FSHandle,value:string)                                                                                  : boolean                                       Writes the specified data to an open file descriptor with the specified handle.
---  @field spaceTotal           fun()                                                                                                              : integer                                       The overall capacity of the file system, in bytes.
---  @field isDirectory          fun(path:string)                                                                                                   : boolean                                       Returns whether the object at the specified absolute path in the file system is a directory.
---  @field rename               fun(from:string,to:string)                                                                                         : boolean                                       Renames/moves an object from the first specified absolute path in the file system to the second.
---  @field list                 fun(path:string)                                                                                                   : string[]                                      Returns a list of names of objects in the directory at the specified absolute path in the file system.
---  @field lastModified         fun(path:string)                                                                                                   : number                                        Returns the (real world) timestamp of when the object at the specified absolute path in the file system was modified.
---  @field getLabel             fun()                                                                                                              : string                                        Get the current label of the file system.
---  @field remove               fun(path:string)                                                                                                   : boolean                                       Removes the object at the specified absolute path in the file system.
---  @field close                fun(handle:FSHandle)                                                                                                                                               Closes an open file descriptor with the specified handle.
---  @field size                 fun(path:string)                                                                                                   : integer                                       Returns the size of the object at the specified absolute path in the file system.
---  @field read                 fun(handle:FSHandle,count:integer)                                                                                 : string|nil                                    Reads up to the specified amount of data from an open file descriptor with the specified handle. Returns nil when EOF is reached. WARNING: Max amount of bytes read is 2048.
---  @field setLabel             fun(value:string)                                                                                                  : string                                        Sets the label of the file system. Returns the new value, which may be truncated.

---@alias DataProxy DataCard1Proxy | DataCard2Proxy | DataCard3Proxy
---@class DataCard1Proxy : Proxy
--- @field type "datacard"
---  @field crc32                fun(data:string)                                                                                                   : string                                        T1. Computes CRC-32 hash of the data. Result is in binary format.
---  @field decode64             fun(data:string)                                                                                                   : string                                        T1. Applies base64 decoding to the data.
---  @field encode64             fun(data:string)                                                                                                   : string                                        T1. Applies base64 encoding to the data. Result is in binary format.
---  @field md5                  fun(data:string)                                                                                                   : string                                        T1. Computes MD5 hash of the data. Result is in binary format
---  @field sha256               fun(data:string)                                                                                                   : string                                        T1. Computes SHA2-256 hash of the data. Result is in binary format.
---  @field deflate              fun(data:string)                                                                                                   : string                                        T1. Applies deflate compression to the data.
---  @field inflate              fun(data:string)                                                                                                   : string                                        T1. Applies inflate decompression to the data.
---  @field getLimit             fun()                                                                                                              : number                                        T1. The maximum size of data that can be passed to other functions of the card.
---@class DataCard2Proxy : DataCard1Proxy
---  @field encrypt              fun(data:string,key:string,iv:string)                                                                              : string                                        T2. Applies AES encryption to the data using the key and (preferably) random IV.
---  @field decrypt              fun(data:string,key:string,iv:string)                                                                              : string                                        T2. Reverses AES encryption on the data using the key and the IV.
---  @field random               fun(len:integer)                                                                                                   : string                                        T2. Generates a random binary string of len length.
---@class DataCard3Proxy : DataCard2Proxy
---  @field generateKeyPair      fun(bitLen?:BitLength)                                                                                             : PublicKey,PrivateKey                          T3. Generates a public/private key pair for various cryptiographic functions. Optional second parameter specifies key length, 256 or 384 bits accepted. Key types include “ec-public” and “ec-private”. Keys can be serialized with `key.serialize():string` Keys also contain the function `key.isPublic():boolean`.
---  @field ecdsa                fun(data:string,key:EncryptionKey,sig?:string)                                                                     : string | boolean                              T3. Generates a signiture of data using a private key. If signature is present verifies the signature using the public key, the previously generated signature string and the original string.
---  @field ecdh                 fun(privateKey:PrivateKey,publicKey:PublicKey)                                                                     : string                                        T3. Generates a Diffie-Hellman shared key using the first user's private key and the second user's public key. An example of a basic key relation: `ecdh(userA.private, userB.public) == ecdh(userB.private, userA.public)`
---  @field deserializeKey       fun(data:string,type:string)                                                                                       : EncryptionKey                                 T3. Transforms a key from string to it's arbitrary type.

--#region Data Card Docs

---This card can be used to transmit encrypted data to other in-game or real-life peers. Since we are given the ability to create key-pairs and Diffie-Hellman shared keys, we are able to establish encrypted connections with these peers.
--- ***
---When using key pairs for encryption, the basic concept is this
---
---Preliminary Setup:
---
---(The following items are to be done on the RECEIVER)
---Generate a public key (rPublic) and private key (rPrivate).
---**If no automated key exchange, then you'll need to send rPublic to the SENDER manually.
---***
---The SENDER must:
---
---***Read the RECEIVER's public key (rPublic), unserialize it, and rebuild the key object.
---Generate a public key (sPublic) and private key (sPrivate).
---*Generate an encryption key using rPublic and sPrivate.
---Generate an Initialization Vector (IV).
---Convert sPublic into a string with sPublic.serialize().
---***Serialize the data using the serialization library, then encrypt it using the encryption key and IV.
---Serialize and transmit the message, with sPublic and IV in plain-text.
---***
---The RECEIVER must:
---
---Read the RECEIVER's private key (rPrivate), unserialize it, and rebuild the key object.
---Receive the message and unserialize it using the serialization library, then deserialize sPublic using data.deserializeKey().
---*Generate a decryption key using sPublic and rPrivate.
---Use the decryption key, along with the IV, to decrypt the message.
---Unserialize the decrypted data.
---NOTE* In the above, the terms 'encryption key' and 'decryption key' are used. These keys are, byte-for-byte, the same. This is because both keys were generated using the ecdh() function.
---
---NOTE** In the above, it is stated that you will manually transfer rPublic to SENDER. This would not be the case in systems that employ a handshake protocol. For example, SENDER would make themselves known to RECEIVER, who will then reply to SENDER with a public key (and possibly additional information, such as key-length). For simplicity, the following examples will not cover the functions of handshake protocols.
---
---NOTE*** The examples above and below state that you must serialize/unserialize a key or message. In-general, it is good practice to serialize data (especially when in binary format) before you write it to a file, or transfer it on the network. Serialization makes sure that the binary data is 'escaped', making it safe for your script or shell to read.
---
---To send an encrypted message:
---
---```
---local serialization  = require("serialization")
---local component      = require("component")
---
----- This table contains the data that will be sent to the receiving computer.
----- Along with header information the receiver will use to decrypt the message.
---local __packet =
---{
---    header =
---    {
---        sPublic    = nil,
---        iv         = nil
---    },
--- 
---    data = nil
---}
--- 
----- Read the public key file.
---local file = io.open("rPublic","rb")
--- 
---local rPublic = file:read("*a")
--- 
---file:close()
--- 
----- Unserialize the public key into binary form.
---local rPublic = serialization.unserialize(rPublic)
--- 
----- Rebuild the public key object.
---local rPublic = component.data.deserializeKey(rPublic,"ec-public")
--- 
----- Generate a public and private keypair for this session.
---local sPublic, sPrivate = component.data.generateKeyPair(384)
--- 
----- Generate an encryption key.
---local encryptionKey = component.data.md5(component.data.ecdh(sPrivate, rPublic))
--- 
----- Set the header value 'iv' to a randomly generated 16 digit string.
---__packet.header.iv = component.data.random(16)
--- 
----- Set the header value 'sPublic' to a string.
---__packet.header.sPublic = sPublic.serialize()
--- 
----- The data that is to be encrypted.
---__packet.data = "lorem ipsum"
--- 
----- Data is serialized and encrypted.
---__packet.data = component.data.encrypt(serialization.serialize(__packet.data), encryptionKey, __packet.header.iv)
--- 
----- For simplicity, in this example the computers are using a Linked Card (ocdoc.cil.li/item:linked_card)
---component.tunnel.send(serialization.serialize(__packet))
---To receive the encrypted message:
---
---snippet.lua
---local serialization = require("serialization")
---local component     = require("component")
---local event         = require("event")
--- 
----- Read the private key
---local file = io.open("rPrivate","rb")
--- 
---local rPrivate = file:read("*a")
--- 
---file:close()
--- 
----- Unserialize the private key
---local rPrivate = serialization.unserialize(rPrivate)
--- 
----- Rebuild the private key object
---local rPrivate = component.data.deserializeKey(rPrivate,"ec-private")
--- 
----- Use event.pull() to receive the message from SENDER.
---local _, _, _, _, _, message = event.pull("modem_message")
--- 
----- Unserialize the message
---local message = serialization.unserialize(message)
--- 
----- From the message, deserialize the public key.
---local sPublic = component.data.deserializeKey(message.header.sPublic,"ec-public")
--- 
----- Generate the decryption key.
---local decryptionKey = component.data.md5(component.data.ecdh(rPrivate, sPublic))
--- 
----- Use the decryption key and the IV to decrypt the encrypted data in message.data
---local data = component.data.decrypt(message.data, decryptionKey, message.header.iv)
--- 
----- Unserialize the decrypted data.
---local data = serialization.unserialize(data)
--- 
----- Print the decrypted data.
---print(data)
---```
---@class DataCard1Proxy

--#endregion

--#region Computer

---This API mainly provides information about the computer a Lua state is running on, such as its address and uptime. It also contains functions for user management. This could belong to the os table, but in order to keep that “clean” it's in its own API.
---@class ComputerAPI
---  @field address     fun()                : ID      The component address of this computer.
---  @field tmpAddress  fun()                : ID|nil  The component address of the computer's temporary file system (if any), used for mounting it on startup.
---  @field freeMemory  fun()                : integer The amount of memory currently unused, in bytes. If this gets close to zero your computer will probably soon crash with an out of memory error. Note that for OpenOS, it is highly recommended to at least have 1x tier 1.5 RAM stick or more. The os [openos] will boot on a single tier 1 ram stick, but quickly and easily run out of memory.
---  @field totalMemory fun()                : integer The total amount of memory installed in this computer, in bytes.
---  @field energy      fun()                : number  The amount of energy currently available in the network the computer is in. For a robot this is the robot's own energy / fuel level.
---  @field maxEnergy   fun()                : number  The maximum amount of energy that can be stored in the network the computer is in. For a robot this is the size of the robot's internal buffer (what you see in the robot's GUI).
---  @field uptime      fun()                : number  The time in real world seconds this computer has been running, measured based on the world time that passed since it was started - meaning this will not increase while the game is paused, for example.
---  @field shutdown    fun(reboot?: boolean)          Shuts down the computer. Optionally reboots the computer, if reboot is true, i.e. shuts down, then starts it again automatically. This function never returns. This example will reboot the computer if it has been running for at least 300 seconds(5 minutes)

---Pushes a new signal into the queue. Signals are processed in a FIFO order. The signal has to at least have a name. Arguments to pass along with it are optional. Note that the types supported as signal parameters are limited to the basic types nil, boolean, number, string, and tables. Yes tables are supported (keep reading). Threads and functions are not supported.
--- ***
---Note that only tables of the supported types are supported. That is, tables must compose types supported, such as other strings and numbers, or even sub tables. But not of functions or threads.
---@param name string
---@param ... Serializable?
function computer.pushSignal(name,...)
end

---Tries to pull a signal from the queue, waiting up to the specified amount of time before failing and returning nil. If no timeout is specified waits forever.
--- ***
---The first returned result is the signal name, following results correspond to what was pushed in pushSignal, for example. These vary based on the event type. Generally it is more convenient to use event.pull from the event library. The return value is the very same, but the event library provides some more options.
---@param timeout number?
---@return string,Serializable ...
function computer.pullSignal(timeout)
end

---if `frequency` is a number it value must be between 20 and 2000.
--- ***
---Causes the computer to produce a beep sound at `frequency` Hz for `duration` seconds. This method is overloaded taking a single string parameter as a pattern of dots `.` and dashes `-` for short and long beeps respectively.
---@overload fun(frequency?: number, duration?: number)
---@overload fun(sequence: string) Takes a single string paramter as a sequence of dots `.` and dashes `-` for short and long beeps respectively.
function computer.beep(frequency, duration)
end

--#endregion

--#region Component

---Returns the documentation string for the method with the specified name of the component with the specified address, if any. Note that you can also get this string by using `tostring` on a method in a proxy, for example `tostring(component.screen.isOn)`.
---@param address ID
---@param method string
---@return string
function component.doc(address, method)
end

---Calls the method with the specified name on the component with the specified address, passing the remaining arguments as arguments to that method. Returns the result of the method call, i.e. the values returned by the method. Depending on the called method's implementation this may throw.
---@param address string
---@param method string
---@param ... any
---@return any ...
function component.invoke(address, method, ...)
end

---Returns a table with all components currently attached to the computer, with address as a key and component type as a value. It also provides iterator syntax via `__call`, so you can use it like so: `for address,componentType in component.list() do ... end`
--- ***
---If `filter` is set this will only return components that contain the filter string (this is not a pattern/regular expression). For example, `component.list("red")` will return redstone components.
--- ***
---If `true` is passed as a second parameter, exact matching is enforced, e.g. `red` will *not* match `redstone`.
---@param filter string | componentType?
---@param exact boolean?
---@return ID[]
function component.list(filter, exact)
end

---Returns a table with the names of all methods provided by the component with the specified address. The names are the keys in the table, the values indicate whether the method is called directly or not.
---@param address ID
---@return string[]
function component.methods(address) end

---Gets a 'proxy' object for a component that provides all methods the component provides as fields, so they can be called more directly (instead of via `invoke`). This is what's used to generate 'primaries' of the individual component types, i.e. what you get via `component.blah`.
--- ***
---For example, you can use it like so: `component.proxy(component.list("redstone")()).getInput(sides.north)`, which gets you a proxy for the first `redstone` component returned by the `component.list` iterator, and then calls `getInput` on it.
--- ***
---Note that proxies will always have at least two fields, `type` with the component's type name, and `address` with the component's address.
---@param address ID
---@return proxy
function component.proxy(address)
end

---Get the component type of the component with the specified address.
---@param address string
---@return componentType
function component.type(address)
end

---Return slot number which the component is installed into. Returns -1 if it doesn't otherwise make sense.
---@param address ID
---@return integer
function component.slot(address)
end

---Undocumented
---@param address ID
---@return string
function component.fields(address)
end

---Tries to resolve an abbreviated address to a full address. Returns the full address on success, or `nil` and an error message otherwise. Optionally filters by component type.
---@param address string
---@param componentType componentType?
---@return ID | nil,string
function component.get(address, componentType)
end

--#endregion

--- Checks if `have` matches one of the types provided in `...`. If not, it throws an error saying that argument `n` is of the wrong type.
---@param n integer
---@param have any
---@param ... any
function checkArg(n, have, ...) end

--- @type ModemProxy
local a = nil