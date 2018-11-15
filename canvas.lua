--require"debug_cdef"
require"anima.utils"
ut = require"anima.common"

ffi = require "ffi"
bit = require "bit"

local gllib = require"gl"
gl, glc, glu, _ = gllib.libraries()

local lfs = require"lfs_ffi"

im = require"imffi"
-- lfs.chdir([[C:\luaGL\iupdlls\]])
-- require("imlua")
-- require("imlua_process")
-------------------------------------------------
gui = require"anima.gui"

--hack for old style iup NotModal
--must be used after GL definition
function NotModal(...)
	return GL:Dialog(...)
end
----------------------------------

require"anima.textures"
--
local function MakeDefaultTimeProvider(GL)
	local tp = {starttime=0,timeoffset = 0,nowtime=0,time = 0, playing = false,totdur = GL.totdur or 200}
	function tp:get_time()
		if self.playing then
			self.nowtime = os.clock()
		end
		self.time = self.nowtime - self.starttime	+ self.timeoffset
		return self.time
	end
	function tp:set_time(val)
		self.timeoffset = val - (self.nowtime - self.starttime)
		--prtable("set_time",self)
	end
	function tp:stop()
		self.playing = false
	end
	function tp:start()
		self.timeoffset = self.time
		self.starttime = os.clock()
		self.playing = true
	end

	return tp
end

function MakeRtaudioTimeProvider(GL,dac, totdur)
	GL.dac = dac
	local tp = {totdur = totdur }
	function tp:get_time()
		return dac:getStreamTime() 
	end
	function tp:set_time(val)
		dac:setStreamTime(val)
	end
	function tp:stop()
		dac:stopStream()
		self.playing = false
	end
	function tp:start()
		dac:startStream()
		self.playing = true
	end

	return tp
end

local sndfile --anchor for not being freed
function PrepareAudio(GL,soundfile,offset,args)--asio,dev_id)
	args = args or {}
	offset = offset or 0
	local dev_id = args.dev_id or 0
	rt = require("RtAudio")
	
	local dac
	if args.asio then
		dac = rt.RtAudio(rt.RtAudio_WINDOWS_ASIO)
	else
		dac = rt.RtAudio(rt.RtAudio_WINDOWS_DS)
	end

	dac:openStream({dev_id,2},nil,44100,1024)
	
	print("RtAudio device info:")
	prtable(dac:getDeviceInfo(dev_id))
	
	sndfile = rt.soundFile(soundfile)
	local DURAMUSICA = sndfile:info().frames/sndfile:info().samplerate
	
	sndfile:play(dac,1,offset)
	
	GL.timeprovider = MakeRtaudioTimeProvider(GL,dac,DURAMUSICA + offset +5 + (args.extratime or 0) )
end
local function newFPScounter(printer,inifps)
	printer = printer or print
	local frames = 0
	local time = 0
	local lasttime = 0
	local counter = {fpsec=inifps or 25}
	function counter:fps(timenow)
		local lapse = timenow - lasttime
		lasttime = timenow
		frames = frames + 1
		time = time + lapse
		if printer == print then
			if time > 1 then
				self.fpsec = frames/time
				printer("FPS",frames/time,time/frames,timenow)
				frames = 0
				time = 0
			end
		else
			--printer(string.format("%5.2f %5.2f",frames/time,timenow))
			--printer(string.format("%5.1f fps ",frames/time))
			if time > 1 then
				self.fpsec = frames/time
				printer(string.format("%5.1f fps ",frames/time))
				frames = 0
				time = 0
			end
		end
	end
	function counter:reset()
		frames = 0
		time = 0
		lasttime = 0
	end
	return counter
end

function ffistr(str)
	if str~=nil then
		return ffi.string(str)
	else
		return nil
	end
end
function print_glinfo()
	print("print_glinfo")


	print("glu.VERSION ",ffistr(glu.gluGetString(glc.GLU_VERSION)))
	print("glu.EXTENSIONS ",ffistr(glu.gluGetString(glc.GLU_EXTENSIONS)))
	GetGLError("in EXTENSIONS 1",true)
	print("gl.VENDOR ",ffistr(gl.glGetString(glc.GL_VENDOR)))
	print("gl.RENDERER ",ffistr(gl.glGetString(glc.GL_RENDERER)))
	print("gl.VERSION ",ffistr(gl.glGetString(glc.GL_VERSION))) 
	--print("gl.EXTENSIONS ",ffistr(gl.glGetString(glc.GL_EXTENSIONS)))

	local n = ffi.new"GLint[1]"
	gl.glGetIntegerv(glc.GL_NUM_EXTENSIONS, n);
	for i = 0,n[0]-1 do
		print(ffistr(glext.glGetStringi(glc.GL_EXTENSIONS, i)));
	end

			GetGLError"in infooooooo"
	-- local nunits = ffi.new("int[1]")
	-- gl.glGetIntegerv(glc.GL_MAX_TEXTURE_UNITS,nunits)
	-- print("GL_MAX_TEXTURE_UNITS",string.format("%d",nunits[0]))
	
	local nunits = ffi.new("int[1]")
	gl.glGetIntegerv(glc.GL_MAX_TEXTURE_IMAGE_UNITS,nunits)
	print("GL_MAX_TEXTURE_IMAGE_UNITS",string.format("%d",nunits[0]))
	

	local colenc = ffi.new("GLint[1]")
	gl.glGetIntegerv(glc.GL_MAX_RENDERBUFFER_SIZE,colenc)
	print("GL_MAX_RENDERBUFFER_SIZE",colenc[0])
	

	gl.glGetIntegerv(glc.GL_MAX_TEXTURE_SIZE,colenc)
	print("GL_MAX_TEXTURE_SIZE",colenc[0])
	local colenc = ffi.new("GLint[2]")
	gl.glGetIntegerv(glc.GL_MAX_VIEWPORT_DIMS,colenc)
	print("GL_MAX_VIEWPORT_DIMS",colenc[0],colenc[1])
	print("GL_SHADING_LANGUAGE_VERSION",ffistr(gl.glGetString(glc.GL_SHADING_LANGUAGE_VERSION)));
	GetGLError("print glinfo end",true)
	
	local NumOfSamples = ffi.new("GLuint[1]")
	gl.glGetIntegerv(glc.GL_MAX_SAMPLES, NumOfSamples);
	print("GL_MAX_SAMPLES",NumOfSamples[0])
end

function GetGLError(str, donterror)
	local iserror = false
	while true do
		local err = gl.glGetError()
		if err ~= glc.GL_NO_ERROR then
			print(str,"GetGLError opengl error:",err)
			print((glu.gluErrorString(err)==nil) and "unknown error" or ffi.string(glu.gluErrorString(err)))
			iserror = true 
			if not donterror then error("opengl error",2) end
		else
			break;
		end
	end
	return iserror
end


require"anima.camera"
require"anima.animation"
local function GuiInitSDL(GL)
	GL.Impl = ig.Imgui_Impl_SDL_opengl3()
	
	GL.Impl:Init(GL.window, GL.gl_context)
	ig.GetIO().ConfigFlags = ig.GetIO().ConfigFlags + imgui.ImGuiConfigFlags_NavEnableKeyboard
	
	GL.Ficons = gui.FontIcons(GL)
	GL.set_imgui_fonts()
	ig.lib.ImGui_ImplOpenGL3_CreateDeviceObjects()
	GL.cursors = GL.Ficons:GetCursors()
	
	GL.transport = gui.ImGui_Transport(GL)
	function GL.key_callback(window, key,  scancode,  action,  mods)
		if scancode == sdl.SCANCODE_F1 and action == sdl.PRESSED then
			local IsFullscreen = bit.band(sdl.getWindowFlags(GL.window), sdl.WINDOW_FULLSCREEN)~=0;
			sdl.setWindowFullscreen(GL.window,IsFullscreen and 0 or sdl.WINDOW_FULLSCREEN_DESKTOP)
		elseif (scancode == sdl.SCANCODE_F2 and action == sdl.PRESSED) then
			GL.show_imgui = not GL.show_imgui
		elseif (scancode == sdl.SCANCODE_SPACE and action == sdl.PRESSED) then
			GL.transport.play()
		elseif GL.tool == "glass" then
			if scancode == sdl.SCANCODE_LALT  then
				if  action == sdl.PRESSED then
					GL:SetCursor(GL.cursors.glass_m);
				elseif action == sdl.RELEASED then
					GL:SetCursor( GL.cursors.glass_p);
				end 
			elseif scancode == sdl.SCANCODE_LCTRL then
				if action == sdl.PRESSED then
					GL:SetCursor( GL.cursors.glass);
				elseif action == sdl.RELEASED then
					GL:SetCursor( GL.cursors.glass_p);
				end
			end
		end
	end
	local function toGLcoords(x,y)
		local wsx,wsy = GL:getWindowSize()
		return x,wsy - y - 1
	end
	
	GL.mxpos = ffi.new"double[1]"
	GL.mypos = ffi.new"double[1]"
	GL.mouse_but = {0,0,0}
	function GL.mouse_button_callbak(win, button, action,mods,x,y)

		if button == sdl.BUTTON_LEFT then
			GL.mouse_but[1] = (action == sdl.PRESSED) and 1 or 0
		end

		--GL.Impl.MouseButtonCallback(win, button, action, mods)
		--dont process mouse if used by imgui
		if imgui.igGetIO().WantCaptureMouse then return end
		
		--glfw.glfwGetCursorPos(win, GL.mxpos,GL.mypos)
		GL.mxpos[0],GL.mypos[0] = x,y
		local X,Y = toGLcoords(GL.mxpos[0],GL.mypos[0])
		
		if GL.mouse_pick and button == sdl.BUTTON_LEFT and action == sdl.PRESSED then
			GL.pick_mouse_coords = {X,Y}
		elseif GL.mouse_pick and button == sdl.BUTTON_LEFT and GL.mouse_pick.action_rel and action == sdl.RELEASED then
			local mouse_pick = GL.mouse_pick
			--GL.mouse_pick = nil
			mouse_pick.action_rel(X,Y)
		elseif GL.tool == "hand" then
			if button == sdl.BUTTON_LEFT and action == sdl.PRESSED then
				GL.get_off_XY = {x=X,y=Y}
			elseif button == sdl.BUTTON_LEFT and action == sdl.RELEASED then
				GL.get_off_XY = nil
			end
		elseif GL.tool == "glass" then
			if button == sdl.BUTTON_LEFT and action == sdl.PRESSED then
				local modst = sdl.getModState()
				if bit.band(modst ,sdl.KMOD_ALT)~=0 then

					GL.offX = 0.5*GL.scale*X + GL.offX
					GL.offY = 0.5*GL.scale*Y + GL.offY
					GL.scale = GL.scale * 0.5
				elseif bit.band(modst ,sdl.KMOD_CTRL)~=0 then
				
					GL.scale = 1
					GL.offX = 0
					GL.offY = 0
				else
					GL:SetCursor( GL.cursors.glass_p);
					GL.offX = -GL.scale*X + GL.offX
					GL.offY = -GL.scale*Y + GL.offY
					GL.scale = GL.scale * 2

				end
			end
		end
	end
	GL.mouse_pos = {0,0}
	function GL.cursor_pos_callback(win, xpos, ypos)
		GL.mouse_pos = {xpos,ypos}
		if GL.get_off_XY then
			xpos,ypos = toGLcoords(xpos, ypos)
			GL.offX = GL.offX + xpos - GL.get_off_XY.x
			GL.offY = GL.offY + ypos - GL.get_off_XY.y
			GL.get_off_XY.x = xpos
			GL.get_off_XY.y = ypos
		end
		if GL.mouse_pos_cb then
			GL.mouse_pos_cb(toGLcoords(xpos, ypos))
		end
	end
end
local function GuiInitGLFW(GL)
	
	GL.Impl = ig.Imgui_Impl_glfw_opengl3() 
	--GL.Impl = ig.ImplGlfwGL3()

	print"imgui init"
	GL.Impl:Init(GL.window, false)
	ig.GetIO().ConfigFlags = ig.GetIO().ConfigFlags + imgui.ImGuiConfigFlags_NavEnableKeyboard
	print"imgui init done"
	
	GL.Ficons = gui.FontIcons(GL)
	GL.set_imgui_fonts()
	ig.lib.ImGui_ImplOpenGL3_CreateDeviceObjects()
	GL.cursors = GL.Ficons:GetCursors()
	
	GL.transport = gui.ImGui_Transport(GL)

	local saved_w_sett = { xpos = ffi.new"int[1]", ypos = ffi.new"int[1]",width = ffi.new"int[1]",height = ffi.new"int[1]"}
	local function key_callback(window, key,  scancode,  action,  mods)
		if (key == glfwc.GLFW_KEY_F1 and action == glfwc.GLFW_PRESS) then
			local monitor = glfw.glfwGetWindowMonitor(window) 
			print("F1",monitor,monitor==nil)

			if monitor ~= nil then --we are in fullscreen
				print"seting windowscreen"
				--local mode = glfw.glfwGetVideoMode(monitor);
				glfw.glfwSetWindowMonitor(window, nil, 
				saved_w_sett.xpos[0], saved_w_sett.ypos[0], saved_w_sett.width[0],saved_w_sett.height[0], 0);
			else
				--save position and size
				glfw.glfwGetWindowPos(window, saved_w_sett.xpos, saved_w_sett.ypos)
				glfw.glfwGetWindowSize(window, saved_w_sett.width, saved_w_sett.height)
				print"setting fullscreen"
				monitor = glfw.glfwGetPrimaryMonitor() 
				local mode = glfw.glfwGetVideoMode(monitor);			
				glfw.glfwSetWindowMonitor(window, monitor, 0, 0, mode.width, mode.height, mode.refreshRate);
			end
		elseif (key == glfwc.GLFW_KEY_F2 and action == glfwc.GLFW_PRESS) then
			GL.show_imgui = not GL.show_imgui
		elseif (key == glfwc.GLFW_KEY_SPACE and action == glfwc.GLFW_PRESS) then
			GL.transport.play()
		elseif GL.tool == "glass" then
			if key == glfwc.GLFW_KEY_LEFT_ALT  then
				if  action == glfwc.GLFW_PRESS then
					glfw.glfwSetCursor(GL.window, GL.cursors.glass_m);
				elseif action == glfwc.GLFW_RELEASE then
					glfw.glfwSetCursor(GL.window, GL.cursors.glass_p);
				end 
			elseif key == glfwc.GLFW_KEY_LEFT_CONTROL then
				if action == glfwc.GLFW_PRESS then
					glfw.glfwSetCursor(GL.window, GL.cursors.glass);
				elseif action == glfwc.GLFW_RELEASE then
					glfw.glfwSetCursor(GL.window, GL.cursors.glass_p);
				end
			end
		end
			
		GL.Impl.KeyCallback(window, key,scancode, action, mods);
	end
	
	local function toGLcoords(x,y)
		local wsx,wsy = GL:getWindowSize()
		return x,wsy - y - 1
	end
	
	GL.mxpos = ffi.new"double[1]"
	GL.mypos = ffi.new"double[1]"
	GL.mouse_but = {0,0,0}
	local function mouse_button_callbak(win, button, action,mods)

		if button == glfwc.GLFW_MOUSE_BUTTON_1 then
			GL.mouse_but[1] = (action == glfwc.GLFW_PRESS) and 1 or 0
		end

		GL.Impl.MouseButtonCallback(win, button, action, mods)
		--dont process mouse if used by imgui
		if imgui.igGetIO().WantCaptureMouse then return end
		
		glfw.glfwGetCursorPos(win, GL.mxpos,GL.mypos)
		local X,Y = toGLcoords(GL.mxpos[0],GL.mypos[0])
		
		if GL.mouse_pick and button == glfwc.GLFW_MOUSE_BUTTON_1 and action == glfwc.GLFW_PRESS then
			GL.pick_mouse_coords = {X,Y}
		elseif GL.mouse_pick and button == glfwc.GLFW_MOUSE_BUTTON_1 and GL.mouse_pick.action_rel and action == glfwc.GLFW_RELEASE then
			local mouse_pick = GL.mouse_pick
			--GL.mouse_pick = nil
			mouse_pick.action_rel(X,Y)
		elseif GL.tool == "hand" then
			if button == glfwc.GLFW_MOUSE_BUTTON_1 and action == glfwc.GLFW_PRESS then
				GL.get_off_XY = {x=X,y=Y}
			elseif button == glfwc.GLFW_MOUSE_BUTTON_1 and action == glfwc.GLFW_RELEASE then
				GL.get_off_XY = nil
			end
		elseif GL.tool == "glass" then
			if button == glfwc.GLFW_MOUSE_BUTTON_1 and action == glfwc.GLFW_PRESS then
				if mods == glfwc.GLFW_MOD_ALT then

					GL.offX = 0.5*GL.scale*X + GL.offX
					GL.offY = 0.5*GL.scale*Y + GL.offY
					GL.scale = GL.scale * 0.5
				elseif mods == glfwc.GLFW_MOD_CONTROL then
				
					GL.scale = 1
					GL.offX = 0
					GL.offY = 0
				else
					glfw.glfwSetCursor(GL.window, GL.cursors.glass_p);
					GL.offX = -GL.scale*X + GL.offX
					GL.offY = -GL.scale*Y + GL.offY
					GL.scale = GL.scale * 2

				end
			end
		end

	end
	GL.mouse_pos = {0,0}
	local function cursor_pos_callback(win, xpos, ypos)
		GL.mouse_pos = {xpos,ypos}
		if GL.get_off_XY then
			xpos,ypos = toGLcoords(xpos, ypos)
			GL.offX = GL.offX + xpos - GL.get_off_XY.x
			GL.offY = GL.offY + ypos - GL.get_off_XY.y
			GL.get_off_XY.x = xpos
			GL.get_off_XY.y = ypos
		end
		if GL.mouse_pos_cb then
			GL.mouse_pos_cb(toGLcoords(xpos, ypos))
		end
	end
	local window = GL.window
	window:setCursorPosCallback(cursor_pos_callback)
	window:setMouseButtonCallback( mouse_button_callbak);
    window:setScrollCallback(GL.Impl.ScrollCallback) -- imgui.ImGui_ImplGlfwGL3_ScrollCallback);
	window:setSizeCallback(GL.OnResize);
	window:setCharCallback(GL.Impl.CharCallback) --imgui.ImGui_ImplGlfwGL3_CharCallback);
	window:setKeyCallback(key_callback);
	print"Imgui inited"
	GetGLError"GuiInit"
end
local function GuiInit(GL)
	if GL.SDL then GuiInitSDL(GL)
	else GuiInitGLFW(GL)
	end
end
--------------------------------------------------------------------------------------------
function GLcanvas(GL)

	GL.fps = GL.fps or 25
	GL.FPScounter = newFPScounter(print,GL.fps)
	GL.globaltime = ffi.new"float[1]"
	GL.save_image = pointer("")
	GL.draw = function() end
	
	if GL.H and GL.aspect then
		GL.W = GL.H * GL.aspect
	elseif GL.W and GL.aspect then
		GL.H = GL.W / GL.aspect
	elseif GL.W and GL.H then
		GL.aspect = GL.W / GL.H
	else
		error("GL without sizes")
	end
	
	if GL.use_fbo == nil then GL.use_fbo=true end
	
	GL.viewH = GL.viewH or GL.H
	GL.viewW = GL.viewH * GL.aspect
	--Lupa
	GL.scale = 1
	GL.offX = 0
	GL.offY = 0
	
	GL.profile = GL.profile or "COMPAT" --"ANY"
	
	--lj_glfw.init()
	
	GL.gl_version = GL.gl_version or {3,3} --{1,0}
	
	GL.postdraw = function() end
	GL.keyframers = {}
	GL.animated_keyframers = {}
	if not GL.not_imgui then gui.SetImGui(GL) end


	
	function GL:set_WH(W,H)
		W = W or self.W
		H = H or self.H
		print("set_WH",W,H)
		self.W = W 
		self.H = H 
		self.aspect = W/H
		if self.fbo then self.fbo:delete() end--TODO check _gc
		self.fbo = initFBO(W,H) --,{SRGB=self.SRGB}) 
		if self.SRGB then
			if self.srgb_fbo then self.srgb_fbo:delete() end--TODO check _gc
			self.srgb_fbo = initFBO(W,H,{SRGB=true}) 
		end
		self.OnResize(self.window,self:getWindowSize()) --calculate viewW etc
		if self.plugins then
		for i,p in ipairs(self.plugins) do
			p.res = {W,H}
		end
		end
	end

	function GL:setMovie(dir,format,ext)
		format = format or "TIFF"
		ext = ext or ".tif"
		self.movie = require"anima.movie":new{directory=dir,ext=ext,format=format,GL=self}
	end

	function GL:SaveImage(filename,formato) --,w,h)
		local oldfboread
		if self.SRGB then
			gl.glEnable(glc.GL_FRAMEBUFFER_SRGB)
			--self.fbo:Dump(self.srgb_fbo.fb[0])
			self.srgb_fbo:Bind()
			ut.Clear()
			self.fbo:GetTexture():blit(self.W,self.H)
			self.srgb_fbo:UnBind()
			oldfboread = self.srgb_fbo:BindRead()
			gl.glDisable(glc.GL_FRAMEBUFFER_SRGB)
		else
			oldfboread = self.fbo:BindRead()
		end
		
		GetGLError"SaveImage"
		local formato = formato or "TIFF"
		local w,h = self.W, self.H
		print("GetImage",w,h)
		local pixelsUserData = ffi.new("char[?]",w*h*4) 
		
		local intformat = glc.GL_RGBA --self.SRGB and glc.GL_SRGB8_ALPHA8 or glc.GL_RGBA
		--if self.SRGB then gl.glEnable(glc.GL_FRAMEBUFFER_SRGB) end
		
		glext.glBindBuffer(glc.GL_PIXEL_PACK_BUFFER,0)
		gl.glPixelStorei(glc.GL_PACK_ALIGNMENT, 1)
		gl.glReadPixels(0,0, w, h, intformat, glc.GL_UNSIGNED_BYTE, pixelsUserData)
		
		--if self.SRGB then gl.glDisable(glc.GL_FRAMEBUFFER_SRGB) end
		glext.glBindFramebuffer(glc.GL_READ_FRAMEBUFFER,oldfboread)

		local image = im.ImageCreateFromOpenGLData(w, h, glc.GL_RGBA, pixelsUserData); 
		--local err = im.FileImageSave(filename,formato,image)
		local err = image:FileSave(filename,formato)
		if (err and err ~= im.ERR_NONE) then
			print("saved",filename)
			error(im.ErrorStr(err))
		end
		--im.ImageDestroy(image)
		image:Destroy()
	end
	
	function GL:SaveImageGet(filename,formato) --,w,h)

		self.fbo:GetTexture():Bind()

		GetGLError"SaveImage"
		local formato = formato or "TIFF"
		local w,h = self.W, self.H
		print("GetImage",w,h)
		local pixelsUserData = ffi.new("char[?]",w*h*4) 
		
		glext.glBindBuffer(glc.GL_PIXEL_PACK_BUFFER,0)
		gl.glPixelStorei(glc.GL_PACK_ALIGNMENT, 1)
		gl.glGetTexImage(glc.GL_TEXTURE_2D, 0, glc.GL_RGBA, glc.GL_UNSIGNED_BYTE, pixelsUserData)

		local image = im.ImageCreateFromOpenGLData(w, h, glc.GL_RGBA, pixelsUserData); 
		local err = image:FileSave(filename,formato)
		if (err and err ~= im.ERR_NONE) then
			print("saved",filename)
			error(im.ErrorStr(err))
		end
		--im.ImageDestroy(image)
		image:Destroy()
	end
	
	function GL:SaveImagePBO(filename,formato)
		formato = formato or "TIFF"
		
		GL.fbo:BindRead()

		local w,h =  self.W, self.H
		local nbytes = w*h*3*ffi.sizeof"char"
		
		local pbo = ffi.new("GLuint[1]")
		glext.glGenBuffers(1,pbo)
		glext.glBindBuffer(glc.GL_PIXEL_PACK_BUFFER, pbo[0]);
		glext.glBufferData(glc.GL_PIXEL_PACK_BUFFER, nbytes, nil, glc.GL_STREAM_READ);
		
		local pixelsUserData = ffi.new("char[?]",w*h*3)
		gl.glPixelStorei(glc.GL_PACK_ALIGNMENT, 1)
		gl.glReadPixels(0,0, w, h, glc.GL_RGB, glc.GL_UNSIGNED_BYTE, ffi.cast("void *",0))
		
		local ptr = glext.glMapBuffer(glc.GL_PIXEL_PACK_BUFFER, glc.GL_READ_ONLY);
		assert(ptr ~= nil,"glMapBuffer error")
		ffi.copy(pixelsUserData, ptr, nbytes)
		glext.glUnmapBuffer(glc.GL_PIXEL_PACK_BUFFER);
		
		glext.glBindBuffer(glc.GL_PIXEL_PACK_BUFFER, 0);
		glext.glDeleteBuffers(1,pbo)
		GetGLError"SaveImagePBO"
		
		local image = imffi.imImageCreateFromOpenGLData(w, h, glc.GL_RGB, pixelsUserData); 
		local err = imffi.imFileImageSave(filename,formato,image)
		if (err and err ~= im.ERR_NONE) then
			print("saved",filename)
			error(im.ErrorStr(err))
		end
		imffi.imImageDestroy(image)
	end
	function GL:SaveImage16(filename,formato,w,h)
		--make sure we read from last draw
		-- local drawbuf = ffi.new("GLint[1]",0)
		-- gl.glGetIntegerv(glc.GL_DRAW_FRAMEBUFFER_BINDING, drawbuf)
		-- glext.glBindFramebuffer(glc.GL_READ_FRAMEBUFFER, drawbuf[0]);
		GL.fbo:BindRead()
		
		local function checkError(err)
			if (err and err ~= im.ERR_NONE) then
				print(filename,err)
				error(im.ErrorStr(err))
			end
		end
		formato = formato or "TIFF"
		w,h = w or self.W, h or self.H
		local pixelsUserData = ffi.new("short[?]",w*h*3)
		glext.glBindBuffer(glc.GL_PIXEL_PACK_BUFFER,0)
		gl.glPixelStorei(glc.GL_PACK_ALIGNMENT, 1)
		gl.glReadPixels(0,0, w, h, glc.GL_RGB, glc.GL_UNSIGNED_SHORT, pixelsUserData)
		
		local err = ffi.new("int[1]")
		local ifile = imffi.imFileNew(filename, formato,err);
		checkError(err[0])
		local err2 = imffi.imFileWriteImageInfo(ifile,w, h, im.RGB + im.PACKED, im.USHORT);
		checkError(err2)
		err2 = imffi.imFileWriteImageData(ifile, pixelsUserData);
		checkError(err2)
		imffi.imFileClose(ifile); 
	end
	
	function GL:SaveImageVICIM(filename)
		local vicim = require"anima.vicimag"
		GL.fbo:BindRead()

		local w,h =  self.W, self.H
		local pixelsUserData = ffi.new("float[?]",w*h*4)
		glext.glBindBuffer(glc.GL_PIXEL_PACK_BUFFER,0)
		gl.glPixelStorei(glc.GL_PACK_ALIGNMENT, 1)
		gl.glReadPixels(0,0, w, h, glc.GL_RGBA, glc.GL_FLOAT, pixelsUserData)
		
		GetGLError"SaveImageVICIM"
		vicim.save(filename,pixelsUserData,w,h,4)

	end
	
	function GL:SaveImageVICIMPBO(filename)
		local vicim = require"anima.vicimag"
		GL.fbo:BindRead()

		local w,h =  self.W, self.H
		local nbytes = w*h*3*ffi.sizeof"float"
		
		local pbo = ffi.new("GLuint[1]")
		glext.glGenBuffers(1,pbo)
		glext.glBindBuffer(glc.GL_PIXEL_PACK_BUFFER, pbo[0]);
		glext.glBufferData(glc.GL_PIXEL_PACK_BUFFER, nbytes, nil, glc.GL_STREAM_READ);
		
		local pixelsUserData = ffi.new("float[?]",w*h*3)
		--gl.glPixelStorei(glc.GL_PACK_ALIGNMENT, 1)
		gl.glReadPixels(0,0, w, h, glc.GL_RGB, glc.GL_FLOAT, ffi.cast("void *",0))
		
		local ptr = glext.glMapBuffer(glc.GL_PIXEL_PACK_BUFFER, glc.GL_READ_ONLY);
      if (nil ~= ptr) then
		ffi.copy(pixelsUserData, ptr, nbytes)
        glext.glUnmapBuffer(glc.GL_PIXEL_PACK_BUFFER);
      else
		error()
	  end
		
		glext.glBindBuffer(glc.GL_PIXEL_PACK_BUFFER, 0);
		GetGLError"SaveImageVICIMPBO"
		vicim.save(filename,pixelsUserData,w,h,3)

	end


	
	function GL:CheckSRGB()
		local framebuffer = ffi.new("GLint[1]",0)
		gl.glGetIntegerv(glc.GL_FRAMEBUFFER_BINDING, framebuffer)
		--only render srgb to screen and if not need to mouse_pick color
		if self.SRGB and framebuffer[0]== 0 and not GL.mouse_pick then
			gl.glEnable(glc.GL_FRAMEBUFFER_SRGB)
		end
	end
	
	function GL:predraw(w,h)
		local timebegin
	
		if GL.DORENDER then
			timebegin = GL.animation:animate()
		else
			timebegin = GL.timeprovider:get_time() 
			GL.animation:animate(timebegin)
		end
		
		for i,v in ipairs(self.animated_keyframers) do v:animate(timebegin) end
		
		GL.globaltime[0] = timebegin

		return timebegin
	end
	
	function GL:get_time()
		return self.globaltime[0] --or 0
	end
	
	local function actionSDL(self)
		local GL = self
		--print("action",self)
		GetGLError"action ini"
		local tbeg = self:predraw(self.W,self.H)
		
		sdl.gL_MakeCurrent(self.window, self.gl_context);
		
		if self.use_fbo then self.fbo:Bind() end
		
		GetGLError"action ini 2"
		self.draw(tbeg, self.W, self.H)
		GetGLError("Error after canvas.draw")--,true)
---[[		
		
		if GL.DORENDER then
			if GL.RENDERINI <= tbeg and GL.RENDEREND >= tbeg then
				GL.movie:SaveFrame(GL,tbeg)
				GetGLError("RENDER")
			end
		end
		
		if GL.save_image[0]~="" then
			GL:SaveImageGet(GL.save_image[0],GL.save_image_type or "TIFF")
			--GL:SaveImage(GL.save_image[0]..".jpg","JPEG")
			--GL:SaveImageVICIMPBO(GL.save_image[0]..".vic")
			--GL:SaveImageVICIM(GL.save_image[0]..".vic")
			--GL:SaveImagePBO(GL.save_image[0]..".tif")
			GetGLError("save_image")
			print("save:",GL.save_image[0])
			GL.save_image[0] = ""
		end
		
		if true then --not (self.window:getAttrib( glc.GLFW_ICONIFIED)>0) then --iconif
		--strange error on gl.ortho(0,0,0,0...
			if GL.use_fbo then
				glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, 0);
				gl.glClearColor(0.1,0.1,0.1,1)
				ut.Clear()
				gl.glClearColor(0,0,0,1)
				--GL.fbo:GetTexture():drawpos(unpack(GL.stencil_sizes))
				local x,y,w,h = unpack(self.stencil_sizes)
				--[[
				if GL.SRGB then
					GL.fbo:GetTexture():drawposSRGB(x+self.offX,y+self.offY,w*self.scale,h*self.scale)
				else
					GL.fbo:GetTexture():drawpos(x+self.offX,y+self.offY,w*self.scale,h*self.scale)
				end
				--]]
				
				if GL.SRGB then
					gl.glEnable(glc.GL_FRAMEBUFFER_SRGB)
					GL.fbo:GetTexture():drawpos(x+self.offX,y+self.offY,w*self.scale,h*self.scale)
					gl.glDisable(glc.GL_FRAMEBUFFER_SRGB)
				else
					GL.fbo:GetTexture():drawpos(x+self.offX,y+self.offY,w*self.scale,h*self.scale)
				end
				
			end
			GetGLError("fbo_dump")
			--mouse pick
			if GL.mouse_pick and GL.pick_mouse_coords then
				local xm,ym = unpack(GL.pick_mouse_coords)
				local mouse_pick = GL.mouse_pick
				--GL.mouse_pick = nil
				GL.pick_mouse_coords = nil
				mouse_pick.action(xm,ym)
			end
			self:postdraw()
		end --iconif
		
		GetGLError("postdraw")
--]]		
		sdl.gL_SwapWindow(self.window);
		
	end
	local function actionGLFW(self)
		local GL = self
		--print("action",self)
		GetGLError"action ini"
		local tbeg = self:predraw(self.W,self.H)
		
		self.window:makeContextCurrent()
		
		if self.use_fbo then self.fbo:Bind() end
		
		GetGLError"action ini 2"
		self.draw(tbeg, self.W, self.H)
		GetGLError("Error after canvas.draw")--,true)
---[[		
		
		if GL.DORENDER then
			if GL.RENDERINI <= tbeg and GL.RENDEREND >= tbeg then
				GL.movie:SaveFrame(GL,tbeg)
				GetGLError("RENDER")
			end
		end
		
		if GL.save_image[0]~="" then
			GL:SaveImageGet(GL.save_image[0],GL.save_image_type or "TIFF")
			--GL:SaveImage(GL.save_image[0]..".jpg","JPEG")
			--GL:SaveImageVICIMPBO(GL.save_image[0]..".vic")
			--GL:SaveImageVICIM(GL.save_image[0]..".vic")
			--GL:SaveImagePBO(GL.save_image[0]..".tif")
			GetGLError("save_image")
			print("save:",GL.save_image[0])
			GL.save_image[0] = ""
		end
		
		if not (self.window:getAttrib( glfwc.GLFW_ICONIFIED)>0) then --iconif
		--strange error on gl.ortho(0,0,0,0...
			if GL.use_fbo then
				glext.glBindFramebuffer(glc.GL_DRAW_FRAMEBUFFER, 0);
				gl.glClearColor(0.1,0.1,0.1,1)
				ut.Clear()
				gl.glClearColor(0,0,0,1)
				--GL.fbo:GetTexture():drawpos(unpack(GL.stencil_sizes))
				local x,y,w,h = unpack(self.stencil_sizes)
				--[[
				if GL.SRGB then
					GL.fbo:GetTexture():drawposSRGB(x+self.offX,y+self.offY,w*self.scale,h*self.scale)
				else
					GL.fbo:GetTexture():drawpos(x+self.offX,y+self.offY,w*self.scale,h*self.scale)
				end
				--]]
				
				if GL.SRGB then
					gl.glEnable(glc.GL_FRAMEBUFFER_SRGB)
					GL.fbo:GetTexture():drawpos(x+self.offX,y+self.offY,w*self.scale,h*self.scale)
					gl.glDisable(glc.GL_FRAMEBUFFER_SRGB)
				else
					GL.fbo:GetTexture():drawpos(x+self.offX,y+self.offY,w*self.scale,h*self.scale)
				end
				
			end
			GetGLError("fbo_dump")
			--mouse pick
			if GL.mouse_pick and GL.pick_mouse_coords then
				local xm,ym = unpack(GL.pick_mouse_coords)
				local mouse_pick = GL.mouse_pick
				--GL.mouse_pick = nil
				GL.pick_mouse_coords = nil
				mouse_pick.action(xm,ym)
			end
			self:postdraw()
		end --iconif
		
		GetGLError("postdraw")
--]]		
		self.window:swapBuffers()
		
	end
	local function startSDL(self) 

		self:doinit()
		local done = false
		while not done do

			local event = ffi.new"SDL_Event"
			while (sdl.pollEvent(event) ~=0) do
				ig.lib.ImGui_ImplSDL2_ProcessEvent(event);
				if (event.type == sdl.QUIT) then
					done = true;
				end
				if (event.type == sdl.WINDOWEVENT) then 
					if (event.window.event == sdl.WINDOWEVENT_CLOSE and event.window.windowID == sdl.getWindowID(window)) then
						done = true;
					elseif event.window.event == sdl.WINDOWEVENT_SIZE_CHANGED then
						self.OnResize(self.window,event.window.data1,event.window.data2)
					end
				elseif event.type == sdl.KEYDOWN or event.type == sdl.KEYUP then 
					self.key_callback(self.window, event.key.keysym.sym, event.key.keysym.scancode, event.key.state, event.key.keysym.mod)
				elseif event.type ==  sdl.MOUSEBUTTONDOWN or event.type == sdl.MOUSEBUTTONUP then
					local button = event.button
					self.mouse_button_callbak(self.window,button.button,button.state,nil,button.x,button.y)
				elseif event.type == sdl.MOUSEMOTION then
					self.cursor_pos_callback(self.window,event.motion.x,event.motion.y)
				end
			end
			
			self:action()
			
		end

		
		if not GL.not_imgui then self.Impl:destroy() end
		
		--self.window:destroy()
		sdl.destroyWindow(self.window)
		sdl.quit()
		--dont destroy in case multiwindow
		--imgui.igShutdown();
		--lj_glfw.terminate()
	end
	local function startGLFW(self) 

		self:doinit()
		
		while not self.window:shouldClose() do
			lj_glfw.pollEvents()
			self:action()

		end
		-- Destroy the window and deinitialize GLFW.
		--free callbacks??
		--[[
		local window = self.window
		window:setCursorPosCallback(nil)
		window:setMouseButtonCallback( nil);
        window:setScrollCallback( nil);
		window:setSizeCallback(nil);
		window:setCharCallback(nil);
		window:setKeyCallback(nil);
		--]]
		
		if not GL.not_imgui then self.Impl:destroy() end
		
		self.window:destroy()

		--dont destroy in case multiwindow
		--imgui.igShutdown();
		lj_glfw.terminate()
	end
	
	local function GLgetAspectViewport(width,height)
		local GLaspect = GL.aspect
		local aspect = width/height
			
		local newW,newH,xpos,ypos
		if aspect > GLaspect then
			newW,newH = height*GLaspect, height
		elseif aspect < GLaspect then
			newW,newH = width,width/GLaspect
		else
			newW,newH = width, height
		end
		xpos = math.floor(0.5*(width - newW))
		ypos = math.floor(0.5*(height - newH))
		return xpos,ypos,newW,newH
	end
	GL.getAspectViewport = GLgetAspectViewport
	
	local int_buffer = ffi.new("int[2]")
	
	local function OnResize(win,width, height)
		local sizes = {GLgetAspectViewport(width,height)}
		GL.stencil_sizes = sizes
		GL.viewW, GL.viewH = sizes[3],sizes[4]
		-- gl.glScissor(unpack(sizes))
		-- gl.glEnable(glc.GL_SCISSOR_TEST);
		-- gl.glViewport(unpack(sizes))
 
		print("setSizeCallback",width,height)
		print(unpack(sizes))
		--glfw.glfwGetFramebufferSize(win,int_buffer,int_buffer+1)
		--print(int_buffer[0],int_buffer[1])

	end
	
	GL.OnResize = OnResize
	--for converting from window coordinates to GL.fbo coordinates
	function GL:ScreenToViewport(X,Y)
		local x,y,w,h = unpack(self.stencil_sizes)
		return self.W*(X - x)/w,self.H*(Y - y)/h
	end
	
	local function doinitCOMMON(self)
		require"anima.GLSL"
		-----------------------------------------------------------------------------------
		print_glinfo()
		if self.profile == "COMPAT" then

			GetGLError"doinit 2"
			gl.glEnable(glc.GL_TEXTURE_2D)    
			gl.glEnable(glc.GL_DEPTH_TEST);
			--gl.glEnable(glc.GL_POLYGON_SMOOTH)
			--gl.glEnable(glc.GL_LINE_SMOOTH)
			GetGLError"doinit 3"
			gl.glHint(glc.GL_POINT_SMOOTH_HINT,glc.GL_NICEST)
			gl.glHint(glc.GL_LINE_SMOOTH_HINT,glc.GL_NICEST)
			gl.glHint(glc.GL_POLYGON_SMOOTH_HINT,glc.GL_NICEST)
			gl.glHint(glc.GL_PERSPECTIVE_CORRECTION_HINT,glc.GL_NICEST)
			GetGLError"doinit 4"
			gl.glShadeModel(glc.GL_SMOOTH) --gl.FLAT --gl.SMOOTH
	
			--------fog
			GetGLError"preinit fog"
			if GL.fog then
				gl.glEnable(glc.GL_FOG);
				gl.glFog(glc.GL_FOG_MODE,glc.GL_EXP2);--gl.LINEAR
				gl.glFog(glc.GL_FOG_COLOR,{0, 0, 0, 0});
				gl.glFog(glc.GL_FOG_DENSITY, 0);
				gl.glHint(glc.GL_FOG_HINT,glc.GL_NICEST) --gl.DONT_CARE);
			end
		end
		
		GL.animation:animate(GL.RENDERINI or 0)
		GL.timeprovider:set_time(GL.RENDERINI or 0)
		
		if not self.not_imgui then GuiInit(self) end
		
		if GL.plugins then
			for i,v in ipairs(GL.plugins) do
				if not v.inited then
				print("call init on plugin",v.name)
				if not v.init then
					prtable(v.plug)
				else
					v:init()
				end
				--self.window:makeContextCurrent()
				self:makeContextCurrent()
				self:postdraw()
				io.write(string.format("plug %d\n",i))
				--self.window:swapBuffers()
				self:swapBuffers()
				v.inited = true
				end
			end
		end
		
		if GL.use_fbo then self:set_WH() end
		
		if GL.init then GL.in_init = true;print"GL.init()";GL:init();GL.in_init = false end
		
		if not self.not_imgui then self:set_initial_curr_notmodal() end
		
		
		GetGLError("INIT")
	
	end
	local function doinitSDL(self)
		sdl = require"sdl2"
		local gllib = require"gl"
		gllib.set_loader(sdl)
		gl, glc, glu, glext = gllib.libraries()
		
		self.FPScounter = newFPScounter(function(str) sdl.setWindowTitle(self.window, str) end,self.fps)
		
		if (sdl.init(sdl.INIT_VIDEO+sdl.INIT_TIMER) ~= 0) then
			print(string.format("Error: %s\n", sdl.getError()));
			error()
		end
		--sdl.gL_SetAttribute(sdl.GL_CONTEXT_FLAGS, sdl.GL_CONTEXT_FORWARD_COMPATIBLE_FLAG);
		sdl.gL_SetAttribute(sdl.GL_CONTEXT_PROFILE_MASK, sdl.GL_CONTEXT_PROFILE_COMPATIBILITY);
		sdl.gL_SetAttribute(sdl.GL_DOUBLEBUFFER, 1);
		sdl.gL_SetAttribute(sdl.GL_DEPTH_SIZE, 24);
		sdl.gL_SetAttribute(sdl.GL_STENCIL_SIZE, 8);
		sdl.gL_SetAttribute(sdl.GL_CONTEXT_MAJOR_VERSION, self.gl_version[1]);
		sdl.gL_SetAttribute(sdl.GL_CONTEXT_MINOR_VERSION, self.gl_version[2]);
		
		local window = sdl.createWindow(self.name or "", sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED, self.viewW, self.viewH, sdl.WINDOW_OPENGL+sdl.WINDOW_RESIZABLE); 

		self.window = window
		local gl_context = sdl.gL_CreateContext(window);
		self.gl_context = gl_context
		
		function self:makeContextCurrent() sdl.gL_MakeCurrent(self.window, self.gl_context); end
		function self:swapBuffers() sdl.gL_SwapWindow(self.window); end
		function self:getWindowSize()
			local w,h = ffi.new("int[1]"),ffi.new("int[1]")
			sdl.getWindowSize(self.window,w,h)
			return w[0],h[0]
		end
		function self:SetCursor(c) return sdl.setCursor(c) end
		OnResize(self.window,self:getWindowSize()) --it is not called fist time
		sdl.gL_MakeCurrent(window, gl_context);
		doinitCOMMON(self)
	end
	local function doinitGLFW(self)
		lj_glfw  = require "glfw"
		local gllib = require"gl"
		gllib.set_loader(lj_glfw)
		gl, glc, glu, glext = gllib.libraries()
		glfw = lj_glfw.glfw
		glfwc = lj_glfw.glfwc

		swapped_glc = swap_keyvalue(glc)
		glfw.glfwSetErrorCallback(function(error,description)
			print("GLFW error:",error,ffi.string(description));
		end)
		self.FPScounter = newFPScounter(function(str) glfw.glfwSetWindowTitle(self.window, str) end,self.fps)
		
		lj_glfw.init()
		--glfw.glfwWindowHint(glc.GLFW_CLIENT_API, glc.GLFW_OPENGL_ES_API)
		
		glfw.glfwWindowHint(glfwc.GLFW_CONTEXT_VERSION_MAJOR, self.gl_version[1]);
		glfw.glfwWindowHint(glfwc.GLFW_CONTEXT_VERSION_MINOR, self.gl_version[2]);

		glfw.glfwWindowHint(glfwc.GLFW_OPENGL_PROFILE, glfwc["GLFW_OPENGL_"..self.profile.."_PROFILE"]);

		if jit.os == "OSX" then
			glfw.glfwWindowHint(glfwc.GLFW_OPENGL_FORWARD_COMPAT, glc.GL_TRUE);
		end

		local window = lj_glfw.Window(self.viewW, self.viewH, self.name or "")
		self.window = window
		function self:makeContextCurrent() self.window:makeContextCurrent() end
		function self:swapBuffers() self.window:swapBuffers() end
		function self:getWindowSize() return self.window:getSize() end
		function self:SetCursor(c) return glfw.glfwSetCursor(self.window,c) end
		
		OnResize(self.window,self:getWindowSize()) --it is not called fist time
		self.window:makeContextCurrent()
		GetGLError"doinit ini"
		

		doinitCOMMON(self)
	end
	
	
	function GL:add_plugin(plugin,name)
		if self.in_init then
			plugin:init()
			plugin.inited = true
		end
		print("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxaddplugin: " .. (name or plugin.name or ""))
		self.plugins = self.plugins or {}
		self.plugins[#self.plugins + 1] = plugin --{plugin=plugin,name=name or ""}

		--Log draw
		if self.window then
		self:makeContextCurrent()
		self:postdraw()
		io.write(string.format("GL:add_plugin %s\n",name or ""))
		self:swapBuffers()
		end
	end
	GL.render_source = "master1080"
	GL.comp_source = "compressed1080"
	function GL:Texture()
		local tex = Texture(self.W,self.H)
		tex.GL = self
		local path = require"anima.path"
		function tex:GLLoad(filename)
			local sourcedir = (self.GL.DORENDER and self.GL.render_source) or self.GL.comp_source
			local ext = (self.GL.DORENDER and ".tif") or ".cmp"
			local fname = path.chain(self.GL.rootdir,sourcedir,filename..ext)
			return self:Load(fname,self.GL.SRGB,self.GL.mipmaps)
		end
		return tex
	end
	function GL:make_slab()
		return MakeSlab(self.W,self.H)
	end
	---------
	GL.fbo_pool = {}
	function GL:get_fbo()
		--if empty create
		if #self.fbo_pool > 0 then
			local fbo = self.fbo_pool[1]
			table.remove(self.fbo_pool,1)
			return fbo
		else
			local fbo = initFBO(self.W,self.H,{no_depth=true})
			fbo.release = function(self)
						GL.fbo_pool[#GL.fbo_pool + 1] = self
					end
			return fbo
		end
	end
	---------
	-- wraps plugins.process and process_fbo functions to be called only if is dirty
	-- because changed NM values or new texture provided
	function GL:DirtyWrap()
		for i,p in ipairs(self.plugins) do
			--if not p.NM.isDBox then
			print("DirtyWrap",p.NM,p.NM and p.NM.name or "unman")
			--prtable(p)
			p.oldprocess=p.process
			p.NM.dirty = true
			p.process = function(self,tex,w,h)
				self:set_texsignature(tex)
				if self:IsDirty() then
					--print("call draw",self.NM.name)
					self.oldprocess(self,tex,w,h)
					self.NM.dirty = false
				end
			end
			p.oldprocess_fbo = p.process_fbo
			p.process_fbo = function(self,fbo,tex)
				self:set_texsignature(tex)
				if self:IsDirty() then
					self.oldprocess_fbo(self,fbo,tex)
					fbo:tex():inc_signature()
					self.NM.dirty = false
				end
			end
		end
	end
	GL.timeprovider = MakeDefaultTimeProvider(GL)
	GL.animation = Animation:new({fps = GL.fps})
	----------------------
	if not GL.SDL then 
		GL.doinit = doinitGLFW
		GL.action = actionGLFW
		GL.start = startGLFW
	else
		GL.doinit = doinitSDL
		GL.action = actionSDL
		GL.start = startSDL
	end
	---------------------
	return GL
end
require"anima.font_utils"
