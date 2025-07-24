---@class GlobalMetadataApi
---@field typeDefinitionsSize number
---@field typeDefinitionsOffset number
---@field stringOffset number
---@field fieldDefaultValuesOffset number
---@field fieldDefaultValuesSize number
---@field fieldAndParameterDefaultValueDataOffset number
---@field version number
local GlobalMetadataApi = {


    ---@type table<number, fun(blob : number) : string | number>
    behaviorForTypes = {
        [2] = function(blob)
            return libmain.cpp.GlobalMetadataApi.ReadNumberConst(blob, gg.TYPE_BYTE)
        end,
        [3] = function(blob)
            return libmain.cpp.GlobalMetadataApi.ReadNumberConst(blob, gg.TYPE_BYTE)
        end,
        [4] = function(blob)
            return libmain.cpp.GlobalMetadataApi.ReadNumberConst(blob, gg.TYPE_BYTE)
        end,
        [5] = function(blob)
            return libmain.cpp.GlobalMetadataApi.ReadNumberConst(blob, gg.TYPE_BYTE)
        end,
        [6] = function(blob)
            return libmain.cpp.GlobalMetadataApi.ReadNumberConst(blob, gg.TYPE_WORD)
        end,
        [7] = function(blob)
            return libmain.cpp.GlobalMetadataApi.ReadNumberConst(blob, gg.TYPE_WORD)
        end,
        [8] = function(blob)
            local self = libmain.cpp.GlobalMetadataApi
            return self.version < 29 and self.ReadNumberConst(blob, gg.TYPE_DWORD) or self.ReadCompressedInt32(blob)
        end,
        [9] = function(blob)
            local self = libmain.cpp.GlobalMetadataApi
            return self.version < 29 and libmain.cpp.FixValue(self.ReadNumberConst(blob, gg.TYPE_DWORD)) or self.ReadCompressedUInt32(blob)
        end,
        [10] = function(blob)
            return libmain.cpp.GlobalMetadataApi.ReadNumberConst(blob, gg.TYPE_QWORD)
        end,
        [11] = function(blob)
            return libmain.cpp.GlobalMetadataApi.ReadNumberConst(blob, gg.TYPE_QWORD)
        end,
        [12] = function(blob)
            return libmain.cpp.GlobalMetadataApi.ReadNumberConst(blob, gg.TYPE_FLOAT)
        end,
        [13] = function(blob)
            return libmain.cpp.GlobalMetadataApi.ReadNumberConst(blob, gg.TYPE_DOUBLE)
        end,
        [14] = function(blob)
            local self = libmain.cpp.GlobalMetadataApi
            local length, offset = 0, 0
            if self.version >= 29 then
                length, offset = self.ReadCompressedInt32(blob)
            else
                length = self.ReadNumberConst(blob, gg.TYPE_DWORD) 
                offset = 4
            end

            if length ~= -1 then
                return libmain.cpp.Utf8ToString(blob + offset, length)
            end
            return ""
        end
    },


    ---@param self GlobalMetadataApi
    ---@param index number
    GetStringFromIndex = function(self, index)
        local stringDefinitions = libmain.cpp.globalMetadataStart + self.stringOffset
        return libmain.cpp.Utf8ToString(stringDefinitions + index)
    end,


    ---@param self GlobalMetadataApi
    GetClassNameFromIndex = function(self, index)
        if (self.version < 27) then
            local typeDefinitions = libmain.cpp.globalMetadataStart + self.typeDefinitionsOffset
            index = (self.typeDefinitionsSize * index) + typeDefinitions
        else
            index = libmain.cpp.FixValue(index)
        end
        local typeDefinition = gg.getValues({{
            address = index,
            flags = gg.TYPE_DWORD
        }})[1].value
        return self:GetStringFromIndex(typeDefinition)
    end,


    ---@param self GlobalMetadataApi
    ---@param dataIndex number
    GetFieldOrParameterDefalutValue = function(self, dataIndex)
        return self.fieldAndParameterDefaultValueDataOffset + libmain.cpp.globalMetadataStart + dataIndex
    end,


    ---@param self GlobalMetadataApi
    ---@param index string
    Getlibmain.cppFieldDefaultValue = function(self, index)
        gg.clearResults()
        gg.setRanges(0)
        gg.setRanges(gg.REGION_C_HEAP | gg.REGION_C_HEAP | gg.REGION_ANONYMOUS | gg.REGION_C_BSS | gg.REGION_C_DATA |
                         gg.REGION_OTHER | gg.REGION_C_ALLOC)
        gg.searchNumber(index, gg.TYPE_DWORD, false, gg.SIGN_EQUAL,
            libmain.cpp.globalMetadataStart + self.fieldDefaultValuesOffset,
            libmain.cpp.globalMetadataStart + self.fieldDefaultValuesOffset + self.fieldDefaultValuesSize)
        if gg.getResultsCount() > 0 then
            local libmain.cppFieldDefaultValue = gg.getResults(1)
            gg.clearResults()
            return libmain.cppFieldDefaultValue
        end
        return {}
    end,

    
    ---@param Address number
    ReadCompressedUInt32 = function(Address)
        local val, offset = 0, 0
        local read = gg.getValues({
            { -- [1]
                address = Address, 
                flags = gg.TYPE_BYTE
            },
            { -- [2]
                address = Address + 1, 
                flags = gg.TYPE_BYTE
            },
            { -- [3]
                address = Address + 2, 
                flags = gg.TYPE_BYTE
            },
            { -- [4]
                address = Address + 3, 
                flags = gg.TYPE_BYTE
            }
        })
        local read1 = read[1].value & 0xFF
        offset = 1
        if (read1 & 0x80) == 0 then
            val = read1
        elseif (read1 & 0xC0) == 0x80 then
            val = (read1 & ~0x80) << 8
            val = val | (read[2].value & 0xFF)
            offset = offset + 1
        elseif (read1 & 0xE0) == 0xC0 then
            val = (read1 & ~0xC0) << 24
            val = val | ((read[2].value & 0xFF) << 16)
            val = val | ((read[3].value & 0xFF) << 8)
            val = val | (read[4].value & 0xFF)
            offset = offset + 3
        elseif read1 == 0xF0 then
            val = gg.getValues({{address = Address + 1, flags = gg.TYPE_DWORD}})[1].value
            offset = offset + 4
        elseif read1 == 0xFE then
            val = 0xffffffff - 1
        elseif read1 == 0xFF then
            val = 0xffffffff
        end
        return val, offset
    end,


    ---@param Address number
    ReadCompressedInt32 = function(Address)
        local encoded, offset = libmain.cpp.GlobalMetadataApi.ReadCompressedUInt32(Address)

        if encoded == 0xffffffff then
            return -2147483647 - 1
        end

        local isNegative = (encoded & 1) == 1
        encoded = encoded >> 1
        if isNegative then
            return -(encoded + 1)
        end
        return encoded, offset
    end,


    ---@param Address number
    ---@param ggType number @gg.TYPE_
    ReadNumberConst = function(Address, ggType)
        return gg.getValues({{
            address = Address,
            flags = ggType
        }})[1].value
    end,

    
    ---@param self GlobalMetadataApi
    ---@param index number
    ---@return number | string | nil
    GetDefaultFieldValue = function(self, index)
        local libmain.cppFieldDefaultValue = self:Getlibmain.cppFieldDefaultValue(tostring(index))
        if #libmain.cppFieldDefaultValue > 0 then
            local _libmain.cppFieldDefaultValue = gg.getValues({
                { -- TypeIndex [1]
                    address = libmain.cppFieldDefaultValue[1].address + 4,
                    flags = gg.TYPE_DWORD,
                },
                { -- dataIndex [2]
                    address = libmain.cppFieldDefaultValue[1].address + 8,
                    flags = gg.TYPE_DWORD
                }
            })
            local blob = self:GetFieldOrParameterDefalutValue(_libmain.cppFieldDefaultValue[2].value)
            local libmain.cppType = libmain.cpp.MetadataRegistrationApi:Getlibmain.cppTypeFromIndex(_libmain.cppFieldDefaultValue[1].value)
            local typeEnum = libmain.cpp.TypeApi:GetTypeEnum(libmain.cppType)
            ---@type string | fun(blob : number) : string | number
            local behavior = self.behaviorForTypes[typeEnum] or "Not support type"
            if type(behavior) == "function" then
                return behavior(blob)
            end
            return behavior
        end
        return nil
    end,


    ---@param name string
    GetPointersToString = function(name)
        local pointers = {}
        gg.clearResults()
        gg.setRanges(0)
        gg.setRanges(gg.REGION_C_HEAP | gg.REGION_C_HEAP | gg.REGION_ANONYMOUS | gg.REGION_C_BSS | gg.REGION_C_DATA |
                         gg.REGION_OTHER | gg.REGION_C_ALLOC)
        gg.searchNumber(string.format("Q 00 '%s' 00", name), gg.TYPE_BYTE, false, gg.SIGN_EQUAL,
            libmain.cpp.globalMetadataStart, libmain.cpp.globalMetadataEnd)
        gg.searchPointer(0)
        pointers = gg.getResults(gg.getResultsCount())
        assert(type(pointers) == 'table' and #pointers > 0, string.format("this '%s' is not in the global-metadata", name))
        gg.clearResults()
        return pointers
    end
}

return GlobalMetadataApi