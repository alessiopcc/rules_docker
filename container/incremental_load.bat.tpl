wsl tr -d "\r" < %{executable_path} > %{executable_path}.sh
wsl %{executable_path}.sh %*
