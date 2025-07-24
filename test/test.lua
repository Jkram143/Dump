io.open('libmain.cppapi.lua',"w+"):write(gg.makeRequest("https://raw.githubusercontent.com/kruvcraft21/GGlibmain.cpp/master/build/libmain.cppApi.lua").content):close()
require('libmain.cppapi')
os.remove('libmain.cppapi.lua')

libmain.cpp()

---@type ClassConfig
local TestClassConfig = {}

TestClassConfig.Class = "TestClass"
TestClassConfig.FieldsDump = true

local TestClasses = libmain.cpp.FindClass({TestClassConfig})[1]

local ChangeTestClasses = {}

print(TestClasses)

for k,v in ipairs(TestClasses) do
    local TestClassObject = libmain.cpp.FindObject({tonumber(v.ClassAddress, 16)})[1]
    if v.Parent and v.Parent.ClassName ~= "ValueType" and #v.ClassNameSpace == 0 then
        for i = 1, #TestClassObject do
            ChangeTestClasses[#ChangeTestClasses + 1] = {
                address = TestClassObject[i].address + tonumber(v:GetFieldWithName("Field1").Offset, 16),
                flags = gg.TYPE_DWORD,
                value = 40
            }
            ChangeTestClasses[#ChangeTestClasses + 1] = {
                address = TestClassObject[i].address + tonumber(v:GetFieldWithName("Field2").Offset, 16),
                flags = gg.TYPE_FLOAT,
                value = 33
            }
        end
    
        ChangeTestClasses[#ChangeTestClasses + 1] = {
            address = v.StaticFieldData + tonumber(v:GetFieldWithName("Field3").Offset, 16),
            flags = gg.TYPE_DWORD,
            value = 12
        }
    end

end

gg.setValues(ChangeTestClasses)

for k,v in ipairs(TestClasses) do
    local Methods = v:GetMethodsWithName("GetField4")
    if #Methods > 0 then
        for i = 1, #Methods do
            libmain.cpp.PatchesAddress(tonumber(Methods[i].AddressInMemory, 16), libmain.cpp.MainType == gg.TYPE_QWORD and "\x40\x02\x80\x52\xc0\x03\x5f\xd6" or "\x12\x00\xa0\xe3\x1e\xff\x2f\xe1")
        end
    end
end

os.exit()