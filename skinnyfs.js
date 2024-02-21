var fs = require("fs")

var dir = "os"

const FLOPPY_CAPACITY = 524_288
const FILE_SIZE = 500_000 //Leave space for skinnyfs unpacker.

var filedata = {}

function recurse(fspath, skpath, depth) {
	depth = depth ?? 0
	console.log(`Dir (${depth}) "${fspath}" -> "${skpath}"`)
	var files_in_dir = fs.readdirSync(fspath);
	for(filename of files_in_dir) {
		var filepath = `${fspath}/${filename}`
		var skfilepath = `${skpath}/${filename}`
		skfilepath = skfilepath.replace(/^\/(.*)$/,"$1")
		var stat = fs.statSync(filepath)
		if(stat.isDirectory() && depth < 16) {
			recurse(filepath, `${skpath}/${skfilepath}`, depth+1)
		} else {
			filedata[skfilepath] = fs.readFileSync(filepath)
			console.log(`Data "${filepath}" -> "${skfilepath}"`)
		}
	}
}

recurse(dir, "");
console.log("File path tree loaded")

var tree_size = 0
for(filepath in filedata) {
	tree_size +=
		1 //Entry length
	+	4 //File address
	+	4 //File length
	+	filepath.length //File path
	+	1 //Path terminating byte
}
tree_size += 1 //terminating null byte
// console.log("Allocating buffers...")

var tree = Buffer.alloc(tree_size)
var tree_addr = 0
// console.log(`${tree_size} -> #tree`)
var data = Buffer.alloc(FILE_SIZE - tree_size)
// console.log(`${data.length} -> #data`)
var data_addr = 0
for(filepath in filedata) {
	var block = filedata[filepath]
	data.write(block.toString(), data_addr)
	// console.log(`Block "${filepath}" -> [${data_addr+tree_size}]`)
	
	var tree_entry_length = 10+filepath.length
	tree.writeUInt8(tree_entry_length, tree_addr)
	tree.writeUInt32LE(data_addr+tree_size+1, tree_addr+1)
	tree.writeUInt32LE(data_addr+tree_size+block.length-1, tree_addr+5)
	tree.write(filepath, tree_addr+9, "ascii")
	tree.writeUint8(0, tree_addr+9+filepath.length)
	tree_addr += tree_entry_length
	
	// console.log(`Tree "${filepath}" (#${tree_entry_length}) -> [${tree_addr}]`)
	
	data_addr += block.length
}

var output = Buffer.concat([tree, data])
var end_byte = output.length
for(let i = output.length-1; i > 0; i--) {
	if(output.readUInt8(i) != 0x00) {
		end_byte = i+1
		break
	}
}
var file_output = output.subarray(0, end_byte)
fs.writeFileSync("skinny.fs", file_output)
fs.copyFileSync("skinny.fs", "floppy/skinny.fs")