local base_dir = "/data/thumbnail/www"
local local_location_prefix = "/local"

local opath, fname, width, height, ext, debug =
ngx.var.opath, ngx.var.fname, ngx.var.width, ngx.var.height, ngx.var.ext, ngx.var.debug

local function check_system_status_code(c)
    return c == 0
end

local function return_server_error(msg)
  ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
  ngx.header["Content-type"] = "text/html"
  ngx.say(msg or "")
  ngx.exit(0)
end

local function return_not_found(msg)
  ngx.status = ngx.HTTP_NOT_FOUND
  ngx.header["Content-type"] = "text/html"
  ngx.say(msg or "not found")
  ngx.exit(0)
end

local function return_orig_pic()
    ngx.exec(
        opath,
        {args = ngx.req.get_uri_args()}
    )
end

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
    -- return true if succeed, else return nil, err_str
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

local function com_cmd_resize(orig_pic_bob, w, h, cmd_getter)
    local src_file = base_dir .. opath
    local dst_uri = opath .. "_" .. w .. "x" .. h
    local dst_file = base_dir .. dst_uri
    local dir = src_file:match("(.*/)")
    if not exist_dir(dir) then
        if not check_system_status_code(os.execute("mkdir -p " .. dir)) then
            -- return_server_error()
            return_orig_pic()
        end
    end
    local src_f = io.open(src_file, "w")
    if not src_f then
        -- return_server_error()
        return_orig_pic()
    end
    src_f:write(orig_pic_bob)
    src_f:close()
    local cmd = cmd_getter(w, h, src_file, dst_file)
    if not check_system_status_code(os.execute(cmd)) then
        if debug then
            ngx.log(ngx.ERR, "exec gm convert failed")
        end
        -- return_server_error()
        return_orig_pic()
    end
    ngx.exec(local_location_prefix .. dst_uri)
end

-- reverse - every 3 bytes get a hex - there hex
local function get_hash_path_from_str(s)
    local s_hash = ngx.md5(s)
    return "/" .. string.sub(s_hash, 1, 3) .. "/" .. string.sub(s_hash, 4, 6) .. "/" .. string.sub(s_hash, 7, 9) .. "/"
end

local function com_stdin_cmd_resize(orig_pic_bob, w, h, cmd_getter)
    local opath_hash_path = get_hash_path_from_str(opath)
    local dir = base_dir .. opath_hash_path
    local dst_uri = opath_hash_path .. fname .. "_" .. w .. "x" .. h .. "." .. ext
    local dst_file = base_dir .. dst_uri
    if not exist_dir(dir) then
        if not check_system_status_code(os.execute("mkdir -p " .. dir)) then
            if debug then
                ngx.log(ngx.ERR, "mkdir failed")
            end
            -- return_server_error()
            return_orig_pic()
        end
    end
    local cmd = cmd_getter(w, h, nil, dst_file)
    local f = io.popen(cmd, "w")
    if not f then
        if debug then
            ngx.log(ngx.ERR, "exec com cmd resize failed")
        end
        -- return_server_error()
        return_orig_pic()
    end
    f:write(orig_pic_bob)
    f:close()
    if exist_file(dst_file) then
        ngx.exec(local_location_prefix .. dst_uri)
    else
        if debug then
            ngx.log(ngx.ERR, "exec com resize - file not found after exec")
        end
        return_orig_pic()
    end
end

-- if use stdin, src_file should be nil
local function gm_cmd_getter(w, h, src_file, dst_file)
    local cmd
    if src_file then
        cmd = "gm convert -resize " .. w .. "x" .. h .. " " .. src_file .. " " .. dst_file
    else
        cmd = "gm convert -resize " .. w .. "x" .. h .. " - " .. dst_file
    end
    return cmd
end

-- if use stdin, src_file should be nil
local function gs_cmd_getter(w, h, src_file, dst_file)
    local cmd
    if src_file then
        cmd = "gifsicle --resize " .. w .. "x" .. h .. " " .. src_file .. " --no-ignore-errors --resize-method catrom -o " .. dst_file
    else
        cmd = "gifsicle --resize " .. w .. "x" .. h .. " --no-ignore-errors --resize-method catrom -o " .. dst_file
    end
    return cmd
end

local function gm_cmd_resize(orig_pic_bob, w, h)
    com_stdin_cmd_resize(orig_pic_bob, w, h, gm_cmd_getter)
end

local function gs_cmd_resize(orig_pic_bob, w, h)
    com_stdin_cmd_resize(orig_pic_bob, w, h, gs_cmd_getter)
end

local function is_gif(orig_pic_bob)
    -- compare whether startswith GIF87a or GIF89a
    local cmp_str = string.sub(orig_pic_bob, 1, 6)
    return cmp_str == "GIF87a" or cmp_str == "GIF89a"
end

local function gm_resize(img, w, h)
    local res, msg, code = img:resize(w, h)
    if not res then
        if debug then
            ngx.log(ngx.ERR, "resize failed, msg is " .. (msg and msg or "") .. ", code is " .. (code and code or ""))
        end
        -- return_server_error()
        return_orig_pic()
    end
    -- if not img:deconstruct() then 
    --     if debug then
    --         ngx.log(ngx.ERR, "decon failed")
    --     end
    --     return_server_error()
    -- end
    -- img:coalesce()
    local blob = img:get_images_blob()
    -- local magick = require("magick")
    -- local blob = magick.thumb(img, w .. "x" .. h)
    ngx.print(blob)
end

local function cv_resize(orig_pic_bob, fmt, w, h)
    local cv = require("opencv")
    -- ngx.log(ngx.ERR, "body length is " .. string.len(res.body) .. "\n")
    -- ngx.log(ngx.ERR, "width is " .. width .. "height is " .. height .. "\n")
    local c = safe_exec(
        cv.load_bytes_image,
        return_orig_pic,
        string.len(orig_pic_bob),
        orig_pic_bob,
        cv.load_image_anydept
    )
    if not c then return_orig_pic() end
    local owidth, oheight = safe_exec(
        c.size,
        return_orig_pic,
        c
    )
    if owidth > w and oheight > h then
        safe_exec(
            c.resize,
            return_orig_pic,
            c,
            w,
            h
        )
    end
    local bs = safe_exec(
        c.get_blob,
        return_orig_pic,
        c,
        "." .. fmt
    )
    if not bs then return_orig_pic() end
    ngx.print(bs)
    c:close()
end

width = tonumber(width)
height = tonumber(height)

if width == 0 and height == 0 then
    return_not_found()
end

local res = ngx.location.capture(
    opath,
    {args = ngx.req.get_uri_args()}
)

if not res or 200 ~= res.status then
    if debug then
        ngx.log(ngx.ERR, "")
    end
    return_not_found()
end

if res.truncated then
    ngx.log(ngx.ERR, "detect truncated\n")
    return_server_error()
end

-- resize the image
-- local magick = require("magick")
-- local image = magick.load_image_from_blob(res.body)
-- if not image then
--     return_server_error()
-- end
-- local format = image:get_format()
-- image = nil

if is_gif(res.body) then
    -- gm_cmd_resize(res.body, width, height)
    -- gm_resize(image, width, height)
    gs_cmd_resize(res.body, width, height)
else
    if ext == "gif" then ext = "jpg" end
    cv_resize(res.body, ext, width, height)
end
