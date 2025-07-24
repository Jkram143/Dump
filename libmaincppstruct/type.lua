local libmain.cppMemory = require("utils.libmain.cppmemory")

---@class TypeApi
---@field Type number
---@field tableTypes table
local TypeApi = {

    
    tableTypes = {
        [1] = "void",
        [2] = "bool",
        [3] = "char",
        [4] = "sbyte",
        [5] = "byte",
        [6] = "short",
        [7] = "ushort",
        [8] = "int",
        [9] = "uint",
        [10] = "long",
        [11] = "ulong",
        [12] = "float",
        [13] = "double",
        [14] = "string",
        [22] = "TypedReference",
        [24] = "IntPtr",
        [25] = "UIntPtr",
        [28] = "object",
        [17] = function(index)
            return libmain.cpp.GlobalMetadataApi:GetClassNameFromIndex(index)
        end,
        [18] = function(index)
            return libmain.cpp.GlobalMetadataApi:GetClassNameFromIndex(index)
        end,
        [29] = function(index)
            local typeMassiv = gg.getValues({
                {
                    address = libmain.cpp.FixValue(index),
                    flags = libmain.cpp.MainType
                },
                {
                    address = libmain.cpp.FixValue(index) + libmain.cpp.TypeApi.Type,
                    flags = gg.TYPE_BYTE
                }
            })
            return libmain.cpp.TypeApi:GetTypeName(typeMassiv[2].value, typeMassiv[1].value) .. "[]"
        end,
        [21] = function(index)
            if not (libmain.cpp.GlobalMetadataApi.version < 27) then
                index = gg.getValues({{
                    address = libmain.cpp.FixValue(index),
                    flags = libmain.cpp.MainType
                }})[1].value
            end
            index = gg.getValues({{
                address = libmain.cpp.FixValue(index),
                flags = libmain.cpp.MainType
            }})[1].value
            return libmain.cpp.GlobalMetadataApi:GetClassNameFromIndex(index)
        end
    },


    ---@param self TypeApi
    ---@param typeIndex number @number for tableTypes
    ---@param index number @for an api that is higher than 24, this can be a reference to the index
    ---@return string
    GetTypeName = function(self, typeIndex, index)
        ---@type string | fun(index : number) : string
        local typeName = self.tableTypes[typeIndex] or string.format('(not support type -> 0x%X)', typeIndex)
        if (type(typeName) == 'function') then
            local resultType = libmain.cppMemory:GetInformationOfType(index)
            if not resultType then
                resultType = typeName(index)
                libmain.cppMemory:SetInformationOfType(index, resultType)
            end
            typeName = resultType
        end
        return typeName
    end,


    ---@param self TypeApi
    ---@param libmain.cppType number
    GetTypeEnum = function(self, libmain.cppType)
        return gg.getValues({{address = libmain.cppType + self.Type, flags = gg.TYPE_BYTE}})[1].value
    end
}

return TypeApi