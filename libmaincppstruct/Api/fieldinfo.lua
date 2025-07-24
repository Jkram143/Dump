local libmain.cppMemory = require("utils.libmain.cppmemory")

---@type FieldInfo
local FieldInfoApi = {


    ---@param self FieldInfo
    ---@return nil | string | number
    GetConstValue = function(self)
        if self.IsConst then
            local fieldIndex = getmetatable(self).fieldIndex
            local defaultValue = libmain.cppMemory:GetDefaultValue(fieldIndex)
            if not defaultValue then
                defaultValue = libmain.cpp.GlobalMetadataApi:GetDefaultFieldValue(fieldIndex)
                libmain.cppMemory:SetDefaultValue(fieldIndex, defaultValue)
            elseif defaultValue == "nil" then
                return nil
            end
            return defaultValue
        end
        return nil
    end
}

return FieldInfoApi