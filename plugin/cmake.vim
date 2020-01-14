

let g:cmake_build_debug		= "build-test"
let g:cmake_build_release	= ""
let g:cmake_build_dir		= ""

let g:cmake_build_mode		= "debug"
let g:cmake_targets			= []
let g:cmake_target_dirs		= {}
let g:cmake_enable = 0

let g:cmake_project_conf = ".cmake_conf.json"

func! LoadJson(path) 
	if !filereadable(a:path)
		echo "open " . path . " failed"
	else
		let lines = readfile(a:path)
		let text = ""
		for line in lines
			let text = text . line
		endfor
		return json_decode(text)
	endif
endfunc

func! SaveJson(path, object)
	writefile([json_encode(a:object)], a:path)
endfunc

func! CMakeInit()
	if filereadable("CMakeLists.txt")
		let g:cmake_enable = 1
		"构建模式
		let g:cmake_build_dir = g:cmake_build_debug
		if g:cmake_build_mode == "release"
			let g:cmake_build_dir = g:cmake_build_release
		endif

		if filereadable(g:cmake_project_conf) 
			let config = LoadJson(g:cmake_project_conf)
			let g:cmake_targets = config["targets"]
			let g:cmake_target_dirs = config["target_dirs"]
			if !empty(g:cmake_targets) 
				return
			endif
		endif

		let api_dir = g:cmake_build_dir . "/.cmake/api/v1"
		let query_file_dir	= api_dir . "/query/client-ncy" 
		let query_file_path = query_file_dir . "/query.json"

		call mkdir(query_file_dir, "p")

		let query = {}
		let query["requests"] =  [{"kind":"codemodel", "version": 2}]
		let query["client"] = {}
		call writefile([json_encode(query)], query_file_path, "w")
		echo "generated query file " . query_file_path 

		let cmd = "cmake -S . -B " . g:cmake_build_dir . " -G \"MinGW Makefiles\""
		echo "loadding symbols ... "
		call system(cmd)
		
		"读取项目信息
		let reply_dir = api_dir . "/reply"
		let reply_files = readdir(reply_dir)
		let reply_text = []
		for file_name in reply_files
			if match(file_name, "codemodel*")  == 0
				echo "readding file " . file_name
				let reply_text = readfile(reply_dir . "/" . file_name)
			endif
		endfor
		let reply_json = ""
		if !empty(reply_text)
			for line in reply_text
				let reply_json = reply_json . line
			endfor
		else
			echo "no reply"
			return
		endif

		let reply = json_decode(reply_json)
		let conf = reply["configurations"][0]
		let targets = conf["targets"]
		let id = 0
		for target in targets
			call add(g:cmake_targets , target["name"])
			let detail = target["jsonFile"]
			let target_conf = LoadJson(reply_dir . "/" . detail)
			let path = target_conf["paths"]["build"]
			let g:cmake_target_dirs[target["name"]] = path
			let id += 1
		endfor
	else
		echo "not a cmake project!"
	endif
endfunc

func! CMakeTargetList(A,L,P)
	if empty(g:cmake_targets)
		call CMakeInit()
	endif
	return g:cmake_targets
endfunc


func! CMakeMRU(target)
	call remove(g:cmake_targets,index(g:cmake_targets, a:target))
	let g:cmake_targets = [a:target] + g:cmake_targets
endfunc

func! CMakeBuild(...)
	if empty(g:cmake_targets) 
		echo "no target to build!"
		return
	endif
	let target = "all"
	if a:0 == 0 
		let target = g:cmake_targets[0]
	else
		let target = a:1 
		call CMakeMRU(target)
	endif
	let cmd =  "!cmake --build " . g:cmake_build_dir . " --target " . target
	exec cmd
endfunc

func! CMakeRun(...)
	let target = ""
	if a:0 == 0
		let target = g:cmake_targets[0]
	else 
		let target = a:1
		call CMakeMRU(target)
	endif
	let exec_dir = g:cmake_build_dir . "/" . g:cmake_target_dirs[target]
	if executable( exec_dir . "/" . target)
		call system("cd " . exec_dir . "&& ./" . target)
	endif
endfunc

func! CMakeSave()
	let config = {}
	let config["targets"] = g:cmake_targets
	let config["target_dirs"] = g:cmake_target_dirs
	let conf_json = json_encode(config)
	call writefile([conf_json], g:cmake_project_conf)
endfunc

func! ShowCenter(lines)
	if empty(a:lines) 
		return
	endif
	let w = winwidth(win_getid())
	let h = winheight(win_getid())
	let uiw = strlen(a:lines[0])
	let uih = len(a:lines)
	let padding_vert = (w - uiw - 1)/2
	let padding_hor = (h - uih - 1)/2
	let ui = []

	let l = 0
	while l < padding_hor
		call add(ui, "")
		let l += 1
	endwhile
	for line in a:lines
		let i = 0
		let pad = ""
		while i < padding_vert
			let pad = pad . " "
			let i += 1
		endwhile
		call add(ui, pad . line)
	endfor
	
	let l = 0
	let left_h = h - padding_hor - len(a:lines)
	while l < left_h 
		call add(ui, "")
		let l += 1
	endwhile

	call setline("$", ui)
endfunc

func! CMakeStartup()
	if argc() == 0
		let ui = []
		call add(ui, "+--------------------------------------------------+")
		call add(ui, "+--------------------------------------------------+")
		call add(ui, "+--------------------------------------------------+")
		call add(ui, "+--------------------------------------------------+")
		call add(ui, "+--------------------------------------------------+")
		call add(ui, "+--------------------------------------------------+")
		call add(ui, "+--------------------------------------------------+")
		call add(ui, "+--------------------------------------------------+")
		call add(ui, "+--------------------------------------------------+")
		call ShowCenter(ui)
	endif
	call CMakeInit()
endfunc

"au BufNewFile,BufRead * call CMakeInit()
au VimEnter * call CMakeStartup()
au VimLeave * call CMakeSave()
nmap <cr> :call CMakeRun()<cr>


command -nargs=0 CMakeInit call CMakeInit()
command -complete=customlist,CMakeTargetList -nargs=? CMakeBuild call CMakeBuild(<f-args>)
command -complete=customlist,CMakeTargetList -nargs=? CMakeRun call CMakeRun(<f-args>)