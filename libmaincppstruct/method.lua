local AndroidInfo = require("utils.androidinfo")
local Protect = require("utils.protect")
local libmain.cppMemory = require("utils.libmain.cppmemory")

---@class MethodsApi
---@field ClassOffset number
---@field NameOffset number
---@field ParamCount number
---@field ReturnType number
---@field Flags number
local MethodsApi = {


    ---@param self MethodsApi
    ---@param MethodName string
    ---@param searchResult MethodMemory
    ---@return MethodInfoRaw[]
    FindMethodWithName = function(self, MethodName, searchResult)
        local FinalMethods = {}
        local MethodNamePointers = libmain.cpp.GlobalMetadataApi.GetPointersToString(MethodName)
        if searchResult.len < #MethodNamePointers then
            for methodPointIndex, methodPoint in ipairs(MethodNamePointers) do
                methodPoint.address = methodPoint.address - self.NameOffset
                local MethodAddress = libmain.cpp.FixValue(gg.getValues({methodPoint})[1].value)
                if MethodAddress > libmain.cpp.libmain.cppStart and MethodAddress < libmain.cpp.libmain.cppEnd then
                    FinalMethods[#FinalMethods + 1] = {
                        MethodName = MethodName,
                        MethodAddress = MethodAddress,
                        MethodInfoAddress = methodPoint.address
                    }
                end
            end
        else
            searchResult.isNew = false
        end
        assert(#FinalMethods > 0, string.format("The '%s' method is not initialized", MethodName))
        return FinalMethods
    end,


    ---@param self MethodsApi
    ---@param MethodOffset number
    ---@param searchResult MethodMemory | nil
    ---@return MethodInfoRaw[]
    FindMethodWithOffset = function(self, MethodOffset, searchResult)
        local MethodsInfo = self:FindMethodWithAddressInMemory(libmain.cpp.libmain.cppStart + MethodOffset, searchResult, MethodOffset)
        return MethodsInfo
    end,


    ---@param self MethodsApi
    ---@param MethodAddress number
    ---@param searchResult MethodMemory
    ---@param MethodOffset number | nil
    ---@return MethodInfoRaw[]
    FindMethodWithAddressInMemory = function(self, MethodAddress, searchResult, MethodOffset)
        local RawMethodsInfo = {} -- the same as MethodsInfo
        gg.clearResults()
        gg.setRanges(gg.REGION_C_HEAP | gg.REGION_C_ALLOC | gg.REGION_ANONYMOUS | gg.REGION_C_BSS | gg.REGION_C_DATA |
                         gg.REGION_OTHER)
        if gg.BUILD < 16126 then
            gg.searchNumber(string.format("%Xh", MethodAddress), libmain.cpp.MainType)
        else
            gg.loadResults({{
                address = MethodAddress,
                flags = libmain.cpp.MainType
            }})
            gg.searchPointer(0)
        end
        local r_count = gg.getResultsCount()
        if r_count > searchResult.len then
            local r = gg.getResults(r_count)
            for j = 1, #r do
                RawMethodsInfo[#RawMethodsInfo + 1] = {
                    MethodAddress = MethodAddress,
                    MethodInfoAddress = r[j].address,
                    Offset = MethodOffset
                }
            end
        else
            searchResult.isNew = false
        end 
        gg.clearResults()
        assert(#RawMethodsInfo > 0, string.format("nothing was found for this address 0x%X", MethodAddress))
        return RawMethodsInfo
    end,


    ---@param self MethodsApi
    ---@param _MethodsInfo MethodInfo[]
    DecodeMethodsInfo = function(self, _MethodsInfo, MethodsInfo)
        for i = 1, #_MethodsInfo do
            local index = (i - 1) * 6
            local TypeInfo = libmain.cpp.FixValue(MethodsInfo[index + 5].value)
            local _TypeInfo = gg.getValues({{ -- type index
                address = TypeInfo + libmain.cpp.TypeApi.Type,
                flags = gg.TYPE_BYTE
            }, { -- index
                address = TypeInfo,
                flags = libmain.cpp.MainType
            }})
            local MethodAddress = libmain.cpp.FixValue(MethodsInfo[index + 1].value)
            local MethodFlags = MethodsInfo[index + 6].value

            _MethodsInfo[i] = {
                MethodName = _MethodsInfo[i].MethodName or
                    libmain.cpp.Utf8ToString(libmain.cpp.FixValue(MethodsInfo[index + 2].value)),
                Offset = string.format("%X", _MethodsInfo[i].Offset or (MethodAddress == 0 and MethodAddress or MethodAddress - libmain.cpp.libmain.cppStart)),
                AddressInMemory = string.format("%X", MethodAddress),
                MethodInfoAddress = _MethodsInfo[i].MethodInfoAddress,
                ClassName = _MethodsInfo[i].ClassName or libmain.cpp.ClassApi:GetClassName(MethodsInfo[index + 3].value),
                ClassAddress = string.format('%X', libmain.cpp.FixValue(MethodsInfo[index + 3].value)),
                ParamCount = MethodsInfo[index + 4].value,
                ReturnType = libmain.cpp.TypeApi:GetTypeName(_TypeInfo[1].value, _TypeInfo[2].value),
                IsStatic = (MethodFlags & libmain.cppFlags.Method.METHOD_ATTRIBUTE_STATIC) ~= 0,
                Access = libmain.cppFlags.Method.Access[MethodFlags & libmain.cppFlags.Method.METHOD_ATTRIBUTE_MEMBER_ACCESS_MASK] or "",
                IsAbstract = (MethodFlags & libmain.cppFlags.Method.METHOD_ATTRIBUTE_ABSTRACT) ~= 0,
            }
        end
    end,


    ---@param self MethodsApi
    ---@param MethodInfo MethodInfoRaw
    UnpackMethodInfo = function(self, MethodInfo)
        return {
            { -- [1] Address Method in Memory
                address = MethodInfo.MethodInfoAddress,
                flags = libmain.cpp.MainType
            },
            { -- [2] Name Address
                address = MethodInfo.MethodInfoAddress + self.NameOffset,
                flags = libmain.cpp.MainType
            },
            { -- [3] Class address
                address = MethodInfo.MethodInfoAddress + self.ClassOffset,
                flags = libmain.cpp.MainType
            },
            { -- [4] Param Count
                address = MethodInfo.MethodInfoAddress + self.ParamCount,
                flags = gg.TYPE_BYTE
            },
            { -- [5] Return Type
                address = MethodInfo.MethodInfoAddress + self.ReturnType,
                flags = libmain.cpp.MainType
            },
            { -- [6] Flags
                address = MethodInfo.MethodInfoAddress + self.Flags,
                flags = gg.TYPE_WORD
            }
        }, 
        {
            MethodName = MethodInfo.MethodName or nil,
            Offset = MethodInfo.Offset or nil,
            MethodInfoAddress = MethodInfo.MethodInfoAddress,
            ClassName = MethodInfo.ClassName
        }
    end,


    FindParamsCheck = {
        ---@param self MethodsApi
        ---@param method number
        ---@param searchResult MethodMemory
        ['number'] = function(self, method, searchResult)
            if (method > libmain.cpp.libmain.cppStart and method < libmain.cpp.libmain.cppEnd) then
                return Protect:Call(self.FindMethodWithAddressInMemory, self, method, searchResult)
            else
                return Protect:Call(self.FindMethodWithOffset, self, method, searchResult)
            end
        end,
        ---@param self MethodsApi
        ---@param method string
        ---@param searchResult MethodMemory
        ['string'] = function(self, method, searchResult)
            return Protect:Call(self.FindMethodWithName, self, method, searchResult)
        end,
        ['default'] = function()
            return {
                Error = 'Invalid search criteria'
            }
        end
    },


    ---@param self MethodsApi
    ---@param method number | string
    ---@return MethodInfo[] | ErrorSearch
    Find = function(self, method)
        local searchResult = libmain.cppMemory:GetInformaionOfMethod(method)
        if not searchResult then
            searchResult = {len = 0}
        end
        searchResult.isNew = true

        ---@type MethodInfoRaw[] | ErrorSearch
        local _MethodsInfo = (self.FindParamsCheck[type(method)] or self.FindParamsCheck['default'])(self, method, searchResult)
        if searchResult.isNew then
            local MethodsInfo = {}
            for i = 1, #_MethodsInfo do
                local MethodInfo
                MethodInfo, _MethodsInfo[i] = self:UnpackMethodInfo(_MethodsInfo[i])
                table.move(MethodInfo, 1, #MethodInfo, #MethodsInfo + 1, MethodsInfo)
            end
            MethodsInfo = gg.getValues(MethodsInfo)
            self:DecodeMethodsInfo(_MethodsInfo, MethodsInfo)

            -- save result
            searchResult.len = #_MethodsInfo
            searchResult.result = _MethodsInfo
            libmain.cppMemory:SetInformaionOfMethod(method, searchResult)
        else
            _MethodsInfo = searchResult.result
        end

        return _MethodsInfo
    end
}

return MethodsApi