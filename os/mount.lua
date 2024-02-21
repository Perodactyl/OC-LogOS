osctl.fs.mount("/", osctl.fs.physicalFS(computer.getBootAddress()))

for addr in osint.component.list("filesystem", true) do
	osctl.fs.mount("/mnt/"..osint.utils.split_p(addr, "%-")[1], osctl.fs.physicalFS(addr))
end