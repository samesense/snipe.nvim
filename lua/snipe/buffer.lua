local M = {}

local Buffer = {
	id = 0,
	name = "",
	classifiers = "     ", -- see :help ls for more info
}

Buffer.__index = Buffer

M.Buffer = Buffer

-- Converts single line from ":buffers" output
function Buffer:from_line(s)
	local o = setmetatable({}, Buffer)

	o.id = tonumber(vim.split(s, " ", { trimempty = true })[1])
	o.classifiers = s:sub(4, 8)

	local ss = s:find('"')
	local se = #s - s:reverse():find('"')

	o.name = s:sub(ss + 1, se)

	return o
end

function M.get_buffers(cmd)
	cmd = cmd or "ls"
	local bufs_out = vim.api.nvim_exec2(cmd, { output = true }).output
	local bufs = vim.split(bufs_out, "\n", { trimempty = true })
	local buffers = vim.tbl_map(function(l)
		return Buffer:from_line(l)
	end, bufs)

	-- Check if run.sh exists and create a buffer entry if not present
	local run_sh_exists = false
	local snakefile_exists = false

	for _, buf in ipairs(buffers) do
		if buf.name == "run.sh" then
			run_sh_exists = true
		end
		if buf.name == "Snakefile.py" then
			snakefile_exists = true
		end
	end

	-- Add run.sh buffer if not present
	if not run_sh_exists then
		if vim.fn.filereadable("run.sh") == 1 then
			local run_sh = setmetatable({}, Buffer)
			run_sh.id = vim.fn.bufadd("run.sh")
			vim.fn.bufload(run_sh.id)
			run_sh.name = "run.sh"
			run_sh.classifiers = "     "
			table.insert(buffers, run_sh)
		end
	end
	-- Add Snakefile.py buffer if not present
	if not snakefile_exists then
		if vim.fn.filereadable("Snakefile.py") == 1 then
			local snakefile = setmetatable({}, Buffer)
			snakefile.id = vim.fn.bufadd("Snakefile.py")
			vim.fn.bufload(snakefile.id)
			snakefile.name = "Snakefile.py"
			snakefile.classifiers = "     "
			table.insert(buffers, snakefile)
		end
	end

	return buffers
end

return M
