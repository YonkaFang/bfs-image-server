package.cpath = package.cpath .. ";../../../lua-opencv/?.so"

local function safe_exec(f, cb, ...)
    local full_res = {pcall(f, ...) }
    local status = table.remove(full_res, 1)
    if status then
        return unpack(full_res)
    else
        if cb then
            return cb()
        end
    end
end

local function exist_file(path)
    if not path then return false end
    return os.rename(path, path)
end

local function exist_dir(path)
    if not exist_file(path) then return false end
    local f = io.open(path)
    if f then
        f:close()
        return true
    end
    return false
end

local function gs_cmd_getter(w, h, src_file, dst_file)
    local cmd = "gifsicle --resize " .. w .. "x" .. h .. " " .. src_file .. " --no-ignore-errors --resize-method catrom -o " .. dst_file
    return cmd
end

local function gs_cmd_resize(src, dst, w, h)
    local cmd = gs_cmd_getter(w, h, src, dst)
    local result = os.execute(cmd)
    if result ~= 0 then
        print(string.format("exec cmd (%s) failed", cmd))
        os.exit(1)
    end
end

local function is_gif(orig_pic_bob)
    -- compare whether startswith GIF87a or GIF89a
    local cmp_str = string.sub(orig_pic_bob, 1, 6)
    return cmp_str == "GIF87a" or cmp_str == "GIF89a"
end

local function cv_resize(orig_pic_bob, dst, fmt, w, h)
    local cv = require("opencv")
    local c = safe_exec(
        cv.load_bytes_image,
        nil,
        string.len(orig_pic_bob),
        orig_pic_bob,
        cv.load_image_anydept
    )
    if not c then
        print("safe_exec(cv.load_bytes_images) failed")
        os.exit(1)
    end
    local owidth, oheight = safe_exec(
        c.size,
        nil,
        c
    )
    if owidth > w and oheight > h then
        safe_exec(
            c.resize,
            nil,
            c,
            w,
            h
        )
    end
    local bs = safe_exec(
        c.get_blob,
        nil,
        c,
        "." .. fmt
    )
    if not bs then
        print("get_blob failed")
        os.exit(1)
    end
    local dst_f = io.open(dst, "wb")
    if not dst_f then
        print(string.format("open dst file (%s) failed", dst))
        os.exit(1)
    end
    dst_f:write(bs)
    dst_f:close()
    c:close()
end

local function read_file_all(file)
    local f = io.open(file, "rb")
    if not f then
        print(string.format("open file %s failed", file))
        return nil, false
    end
    local content = f:read("*all")
    f:close()
    return content, true
end

local src, dst = arg[1], arg[2]

local width, height, ext = string.match(dst, "_(%d+)x(%d+)\.([a-zA-Z0-9]+)$")
width = tonumber(width)
height = tonumber(height)

if not width or not height then
    print("width or height is nil")
    os.exit(1)
end

if width == 0 and height == 0 then
    printf(string.format("width(%d) or height(%d) is 0", width, height))
    os.exit(1)
end

local blob, ok = read_file_all(src)
if not ok then
    print(string.format("read from src (%s) failed", src))
    os.exit(1)
end

if is_gif(blob) then
    gs_cmd_resize(src, dst, width, height)
else
    if ext == "gif" then ext = "jpg" end
    cv_resize(blob, dst, ext, width, height)
end
