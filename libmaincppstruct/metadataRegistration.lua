local Searcher = require("utils.universalsearcher")

---@class MetadataRegistrationApi
---@field metadataRegistration number
---@field types number
local MetadataRegistrationApi = {


    ---@param self MetadataRegistrationApi
    ---@return number
    Getlibmain.cppTypeFromIndex = function(self, index)
        if not self.metadataRegistration then
            self:FindMetadataRegistration()
        end
        local types = gg.getValues({{address = self.metadataRegistration + self.types, flags = libmain.cpp.MainType}})[1].value
        return libmain.cpp.FixValue(gg.getValues({{address = types + (libmain.cpp.pointSize * index), flags = libmain.cpp.MainType}})[1].value)
    end,


    ---@param self MetadataRegistrationApi
    ---@return void
    FindMetadataRegistration = function(self)
        self.metadataRegistration = Searcher.libmain.cppMetadataRegistration()
    end
}

return MetadataRegistrationApi