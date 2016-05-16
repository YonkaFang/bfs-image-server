#include <lua.hpp>
#include <lauxlib.h>

#include <opencv2/opencv.hpp>


static int
image_sharpen(lua_State *L)
{
    return 1;
}


static int
image_blur(lua_State *L)
{
    return 1;
}


static int
image_crop(lua_State *L)
{
    return 1;
}


// static int
// image_get_blob(lua_State *L)
// {
//
//     cv::Mat **m = (cv::Mat **) lua_touserdata(L,1);
// 	if (m == NULL) {
// 		return 0;
// 	}
//     // const char *fmt = luaL_checkstring(L, 2);
//
//     lua_pushlstring(L, (const char*) (**m).data, (**m).total() * (**m).elemSize());
//
//     return 1;
// }

static int
image_get_blob(lua_State *L)
{
    try {
        luaL_Buffer b;

        cv::Mat **m = (cv::Mat **) lua_touserdata(L,1);
        if (m == NULL) {
            return 0;
        }
        const char *fmt = luaL_checkstring(L, 2);

        cv::vector<uchar> buf;
        cv::imencode(fmt, **m, buf);

        luaL_buffinit(L, &b);
        luaL_addlstring(&b, (const char*) &buf[0], buf.size());
        // lua_pushstring(L, "hengheng\n");
        luaL_pushresult(&b);
        return 1;
    } catch (...) {
        return 0;
    }
}


static int
image_resize(lua_State *L)
{
    cv::Mat **m = (cv::Mat **) lua_touserdata(L,1);
	if (m == NULL) {
		return 0;
	}

    int width = luaL_checknumber(L, 2);
    int high = luaL_checknumber(L, 3);
    int flag = luaL_optnumber(L, 4, CV_INTER_AREA);  // LINEAR will increase nearly 100% performace but not that smooth and file will be 30% larger

    if (flag < CV_INTER_NN || flag > CV_INTER_LANCZOS4) {

        return luaL_error(L, "Invalid flag  %d", flag);
    }

    cv::Size ssize = (**m).size();
    if (width <= 0 && high <= 0) {
        return luaL_error(L, "both width %d, high %d are negative", width, high);
    } else if (width <= 0) {
        width = round((ssize.width + 0.0) / ssize.height * high);
    } else if (high <= 0) {
        high = round((ssize.height + 0.0) / ssize.width * width);
    }

    cv::Mat *dm = new cv::Mat(high, width, (*m)->type());  // rows, cols = =

    cv::resize(**m, *dm, dm->size(), 0, 0, flag);
    (*m)->release();
    delete *m;

    *m = dm;

    return 1;
}

static int
image_size(lua_State *L)
{
    cv::Mat **m = (cv::Mat **) lua_touserdata(L,1);
	if (m == NULL) {
		return 0;
	}

    cv::Size ssize = (**m).size();
    lua_pushnumber(L, ssize.width);
    lua_pushnumber(L, ssize.height);

    return 2;
}

static int
image_write(lua_State *L)
{
    cv::Mat **m = (cv::Mat **) lua_touserdata(L,1);
	if (m == NULL) {
		return 0;
	}

    const char *filename = luaL_checkstring(L, 2);

    if (cv::imwrite(filename, **m) == true) {
        return 1;
    }

    return 0;
}

static int
image_close(lua_State *L)
{
    cv::Mat **m = (cv::Mat **) lua_touserdata(L,1);
    if (m == NULL) {
        return 0;
    }
    if (*m != NULL) {
       (*m)->release();
       delete *m;
    }


    //delete m ;
    //m = NULL;
    return 1;
}


static int
image_destroy(lua_State *L)
{
   return image_close(L);
}

static int
load_image(lua_State *L)
{
    const char *filename = luaL_checkstring(L, 1);

    int flag = luaL_optnumber(L, 2, CV_LOAD_IMAGE_COLOR);
    cv::Mat m = cv::imread(filename, flag);

    cv::Mat **ud = (cv::Mat **) lua_newuserdata(L, sizeof(cv::Mat *));
    *ud = new cv::Mat(m);

    if (luaL_newmetatable(L, "opencv")) {
		luaL_Reg l[] = {
			{ "resize", image_resize },
            { "sharpen", image_sharpen },
            { "blur", image_blur },
            { "crop", image_crop },
            { "get_blob", image_get_blob },
            { "write", image_write },
            { "close", image_close },
            { "size", image_size },
            { "__gc", image_destroy },
			{ NULL, NULL },
		};

		// luaL_newlib(L,l);
		luaL_register(L, "opencv", l);
        lua_setfield(L, -2, "__index");
	}

    lua_setmetatable(L, -2);

    return 1;
}

static int
load_bytes_image(lua_State *L)
{
    int len = luaL_checkint(L, 1);
    const char *bs = luaL_checklstring(L, 2, (size_t*)(&len));
    std::vector<char> vec(bs, bs+len);

    int flag = luaL_optnumber(L, 3, -1);  // default value use -1 (<0 Return the loaded image as is (with alpha channel).)
    cv::Mat m = cv::imdecode(vec, flag);

    cv::Mat **ud = (cv::Mat **) lua_newuserdata(L, sizeof(cv::Mat *));
    *ud = new cv::Mat(m);

    if (luaL_newmetatable(L, "opencv")) {
		luaL_Reg l[] = {
			{ "resize", image_resize },
            { "sharpen", image_sharpen },
            { "blur", image_blur },
            { "crop", image_crop },
            { "get_blob", image_get_blob },
            { "write", image_write },
            { "close", image_close },
            { "size", image_size },
            { "__gc", image_destroy },
			{ NULL, NULL },
		};

		// luaL_newlib(L,l);
		luaL_register(L, "opencv", l);
        lua_setfield(L, -2, "__index");

	}

    lua_setmetatable(L, -2);

    return 1;
}
/*
static int
close_opencv(lua_State *L) {
    lua_close(L);
    return 1;
}*/

extern "C" {
    int luaopen_opencv(lua_State *L) {
        //  luaL_checkversion(L);

        luaL_Reg l[] = {
            { "load_image", load_image },
            { "load_bytes_image", load_bytes_image },
            //{ "close",  close_opencv },
            { NULL, NULL}
        };

        // luaL_newlib(L, l);
        luaL_register(L, "opencv", l);

        lua_pushnumber(L, CV_LOAD_IMAGE_ANYDEPTH);
        lua_setfield(L,-2,"load_image_anydepth");

        lua_pushnumber(L, CV_LOAD_IMAGE_ANYDEPTH | CV_LOAD_IMAGE_ANYCOLOR);
        lua_setfield(L,-2,"load_image_anydepth_anycolor");

        lua_pushnumber(L, CV_LOAD_IMAGE_COLOR);
        lua_setfield(L,-2,"load_image_color");

        lua_pushnumber(L, CV_LOAD_IMAGE_UNCHANGED);
        lua_setfield(L,-2,"load_image_unchanged");

        lua_pushnumber(L, CV_LOAD_IMAGE_ANYDEPTH);
        lua_setfield(L,-2,"load_image_anydepth");

        lua_pushnumber(L, CV_INTER_NN);
        lua_setfield(L,-2,"inter_nearest");

        lua_pushnumber(L, CV_INTER_LINEAR);
        lua_setfield(L,-2,"inter_linear");

        lua_pushnumber(L, CV_INTER_AREA);
        lua_setfield(L,-2,"inter_area");

        lua_pushnumber(L, CV_INTER_CUBIC);
        lua_setfield(L,-2,"inter_cubic");

        lua_pushnumber(L, CV_INTER_LANCZOS4);
        lua_setfield(L,-2,"inter_lanczos4");

        return 1;
    }
}
