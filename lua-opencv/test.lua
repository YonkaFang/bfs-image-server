--package.cpath = package.cpath .. ";?.dylib"

local cv  = require "opencv"

local c = cv.load_image("test.png", cv.load_image_anydepth)
if c == nil then
   print("error")
end

c:resize(100, 100)
c:write("out.png")
c:get_blob()
c:close()

