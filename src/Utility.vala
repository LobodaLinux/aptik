/*
 * Utility.vala
 *
 * Copyright 2012 Tony George <teejee2008@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 *
 *
 */

using Gtk;
using Json;
using TeeJee.Logging;
using TeeJee.FileSystem;
using TeeJee.JSON;
using TeeJee.ProcessManagement;
using TeeJee.GtkHelper;
using TeeJee.Multimedia;
using TeeJee.System;
using TeeJee.Misc;

/*
extern void exit(int exit_code);
*/

namespace TeeJee.Logging{

	/* Functions for logging messages to console and log files */

	using TeeJee.Misc;

	public DataOutputStream dos_log;

	public bool LOG_ENABLE = true;
	public bool LOG_TIMESTAMP = true;
	public bool LOG_COLORS = true;
	public bool LOG_DEBUG = false;
	public bool LOG_COMMANDS = false;

	public void log_msg (string message, bool highlight = false){

		if (!LOG_ENABLE) { return; }

		string msg = "";

		if (highlight && LOG_COLORS){
			msg += "\033[1;38;5;34m";
		}

		if (LOG_TIMESTAMP){
			msg += "[" + timestamp() +  "] ";
		}

		msg += message;

		if (highlight && LOG_COLORS){
			msg += "\033[0m";
		}

		msg += "\n";

		stdout.printf (msg);
		stdout.flush();

		try {
			if (dos_log != null){
				dos_log.put_string ("[%s] %s\n".printf(timestamp(), message));
			}
		}
		catch (Error e) {
			stdout.printf (e.message);
		}
	}

	public void log_error (string message, bool highlight = false, bool is_warning = false){
		if (!LOG_ENABLE) { return; }

		string msg = "";

		if (highlight && LOG_COLORS){
			msg += "\033[1;38;5;160m";
		}

		if (LOG_TIMESTAMP){
			msg += "[" + timestamp() +  "] ";
		}

		string prefix = (is_warning) ? _("Warning") : _("Error");

		msg += prefix + ": " + message;

		if (highlight && LOG_COLORS){
			msg += "\033[0m";
		}

		msg += "\n";

		stdout.printf (msg);
		stdout.flush();
		
		try {
			if (dos_log != null){
				dos_log.put_string ("[%s] %s: %s\n".printf(timestamp(), prefix, message));
			}
		}
		catch (Error e) {
			stdout.printf (e.message);
		}
	}

	public void log_debug (string message){
		if (!LOG_ENABLE) { return; }

		if (LOG_DEBUG){
			log_msg (message);
		}
		else{
			try {
				if (dos_log != null){
					dos_log.put_string ("[%s] %s\n".printf(timestamp(), message));
				}
			}
			catch (Error e) {
				stdout.printf (e.message);
			}
		}
	}
}

namespace TeeJee.FileSystem{

	/* Convenience functions for handling files and directories */

	using TeeJee.Logging;
	using TeeJee.FileSystem;
	using TeeJee.ProcessManagement;
	using TeeJee.Misc;

	// path helpers ----------------------------
	
	public string file_parent(string file_path){
		return File.new_for_path(file_path).get_parent().get_path();
	}

	public string file_basename(string file_path){
		return File.new_for_path(file_path).get_basename();
	}

	// file helpers -----------------------------
	
	public bool file_exists (string file_path){
		/* Check if file exists */
		return ( FileUtils.test(file_path, GLib.FileTest.EXISTS) && FileUtils.test(file_path, GLib.FileTest.IS_REGULAR));
	}

	public bool file_delete(string file_path){

		/* Check and delete file */

		try {
			var file = File.new_for_path (file_path);
			if (file.query_exists ()) {
				file.delete ();
			}
			return true;
		} catch (Error e) {
	        log_error (e.message);
	        log_error(_("Failed to delete file") + ": %s".printf(file_path));
	        return false;
	    }
	}

	public string? file_read (string file_path){

		/* Reads text from file */

		string txt;
		size_t size;

		try{
			GLib.FileUtils.get_contents (file_path, out txt, out size);
			return txt;
		}
		catch (Error e){
	        log_error (e.message);
	        log_error(_("Failed to read file") + ": %s".printf(file_path));
	    }

	    return null;
	}

	public bool file_write (string file_path, string contents){

		/* Write text to file */

		try{
			var file = File.new_for_path (file_path);
			if (file.query_exists ()) {
				file.delete ();
			}
			
			var file_stream = file.create (FileCreateFlags.REPLACE_DESTINATION);
			var data_stream = new DataOutputStream (file_stream);
			data_stream.put_string (contents);
			data_stream.close();
			return true;
		}
		catch (Error e) {
			log_error (e.message);
			log_error(_("Failed to write file") + ": %s".printf(file_path));
			return false;
		}
	}

	public bool file_copy (string src_file, string dest_file){
		try{
			var file_src = File.new_for_path (src_file);
			if (file_src.query_exists()) {
				var file_dest = File.new_for_path (dest_file);
				file_src.copy(file_dest,FileCopyFlags.OVERWRITE,null,null);
				return true;
			}
		}
		catch(Error e){
	        log_error (e.message);
	        log_error(_("Failed to copy file") + ": '%s', '%s'".printf(src_file, dest_file));
		}

		return false;
	}

	public void file_move (string src_file, string dest_file){
		try{
			var file_src = File.new_for_path (src_file);
			if (file_src.query_exists()) {
				var file_dest = File.new_for_path (dest_file);
				file_src.move(file_dest,FileCopyFlags.OVERWRITE,null,null);
			}
		}
		catch(Error e){
	        log_error (e.message);
	        log_error(_("Failed to move file") + ": '%s', '%s'".printf(src_file, dest_file));
		}
	}

	public DateTime file_modified_date(string file_path){
		try{
			FileInfo info;
			File file = File.parse_name (file_path);
			if (file.query_exists()) {
				info = file.query_info("%s".printf(FileAttribute.TIME_MODIFIED), 0);
				return (new DateTime.from_timeval_utc(info.get_modification_time())).to_local();
			}
		}
		catch (Error e) {
			log_error (e.message);
		}
		
		return (new DateTime.from_unix_utc(0)); //1970
	}

	// directory helpers ----------------------
	
	public bool dir_exists (string dir_path){
		/* Check if directory exists */
		return ( FileUtils.test(dir_path, GLib.FileTest.EXISTS) && FileUtils.test(dir_path, GLib.FileTest.IS_DIR));
	}
	
	public bool dir_create (string dir_path){

		/* Creates a directory along with parents */

		try{
			var dir = File.parse_name (dir_path);
			if (dir.query_exists () == false) {
				dir.make_directory_with_parents (null);
			}
			return true;
		}
		catch (Error e) {
			log_error (e.message);
			log_error(_("Failed to create dir") + ": %s".printf(dir_path));
			return false;
		}
	}

	public bool dir_tar (string src_dir, string tar_file, bool recursion){
		if (dir_exists(src_dir)) {
			
			if (file_exists(tar_file)){
				file_delete(tar_file);
			}

			var src_parent = file_parent(src_dir);
			var src_name = file_basename(src_dir);
			
			string cmd = "tar cvf '%s' --overwrite --%srecursion -C '%s' '%s'\n".printf(tar_file, (recursion ? "" : "no-"), src_parent, src_name);

			log_debug(cmd);
			
			string stdout, stderr;
			int status = execute_command_script_sync(cmd, out stdout, out stderr);
			if (status == 0){
				return true;
			}
			else{
				log_msg(stderr);
			}
		}
		else{
			log_error(_("Dir not found") + ": %s".printf(src_dir));
		}

		return false;
	}

	public bool dir_untar (string tar_file, string dst_dir){
		if (file_exists(tar_file)) {

			if (!dir_exists(dst_dir)){
				dir_create(dst_dir);
			}
			
			string cmd = "tar xvf '%s' --overwrite --same-permissions -C '%s'\n".printf(tar_file, dst_dir);

			log_debug(cmd);
			
			string stdout, stderr;
			int status = execute_command_script_sync(cmd, out stdout, out stderr);
			if (status == 0){
				return true;
			}
			else{
				log_msg(stderr);
			}
		}
		else{
			log_error(_("File not found") + ": %s".printf(tar_file));
		}
		
		return false;
	}


	//TODO: Deprecated, Remove this
	public bool create_dir (string filePath){

		/* Creates a directory along with parents */

		try{
			var dir = File.parse_name (filePath);
			if (dir.query_exists () == false) {
				dir.make_directory_with_parents (null);
			}
			return true;
		}
		catch (Error e) {
			log_error (e.message);
			return false;
		}
	}

	//TODO: Deprecated, Remove this
	public bool move_file (string sourcePath, string destPath){

		/* Move file from one location to another */

		try{
			File fromFile = File.new_for_path (sourcePath);
			File toFile = File.new_for_path (destPath);
			fromFile.move (toFile, FileCopyFlags.NONE);
			return true;
		}
		catch (Error e) {
			log_error (e.message);
			return false;
		}
	}

	//TODO: Deprecated, Remove this
	public bool copy_file (string sourcePath, string destPath){

		/* Copy file from one location to another */

		try{
			File fromFile = File.new_for_path (sourcePath);
			File toFile = File.new_for_path (destPath);
			fromFile.copy (toFile, FileCopyFlags.NONE);
			return true;
		}
		catch (Error e) {
			log_error (e.message);
			return false;
		}
	}

	//TODO: Deprecated, Remove this
	public string? read_file (string file_path){

		/* Reads text from file */

		string txt;
		size_t size;

		try{
			GLib.FileUtils.get_contents (file_path, out txt, out size);
			return txt;
		}
		catch (Error e){
	        log_error (e.message);
	    }

	    return null;
	}

	//TODO: Deprecated, Remove this
	public bool write_file (string file_path, string contents){

		/* Write text to file */

		try{
			var file = File.new_for_path (file_path);
			if (file.query_exists ()) { file.delete (); }
			var file_stream = file.create (FileCreateFlags.REPLACE_DESTINATION);
			var data_stream = new DataOutputStream (file_stream);
			data_stream.put_string (contents);
			data_stream.close();
			return true;
		}
		catch (Error e) {
			log_error (e.message);
			return false;
		}
	}

	//TODO: Deprecated, Remove this
	public DateTime? get_file_modification_time (string file_path){
		try{
			var file = File.new_for_path (file_path);
			if (file.query_exists()) {
				var info = file.query_info("*",FileQueryInfoFlags.NONE);
				TimeVal modified = info.get_modification_time();
				return new DateTime.from_timeval_local(modified);
			}
			else{
				log_error("File not found: %s".printf(file_path));
			}
		}
		catch (Error e) {
        log_error (e.message);
    }

		return null;
	}

	// archiving and encryption ----------------
	
	public bool file_tar_and_encrypt (string src_file, string dst_file, string password){
		if (file_exists(src_file)) {
			if (file_exists(dst_file)){
				file_delete(dst_file);
			}

			var src_dir = file_parent(src_file);
			var src_name = file_basename(src_file);

			var dst_dir = file_parent(dst_file);
			var dst_name = file_basename(dst_file);
			var tar_name = dst_name[0 : dst_name.index_of(".gpg")];
			var tar_file = "%s/%s".printf(dst_dir, tar_name);
			
			string cmd = "tar cvf '%s' --overwrite -C '%s' '%s'\n".printf(tar_file, src_dir, src_name);
			cmd += "gpg --passphrase '%s' -o '%s' --symmetric '%s'\n".printf(password, dst_file, tar_file);
			cmd += "rm -f '%s'\n".printf(tar_file);

			log_debug(cmd);
			
			string stdout, stderr;
			int status = execute_command_script_sync(cmd, out stdout, out stderr);
			if (status == 0){
				return true;
			}
			else{
				log_msg(stderr);
			}
		}

		return false;
	}

	public bool file_decrypt_and_untar (string src_file, string dst_file, string password){
		if (file_exists(src_file)) {
			if (file_exists(dst_file)){
				file_delete(dst_file);
			}

			var src_dir = file_parent(src_file);
			var src_name = file_basename(src_file);
			var tar_name = src_name[0 : src_name.index_of(".gpg")];
			var tar_file = "%s/%s".printf(src_dir, tar_name);
			
			string cmd = "";
			cmd += "gpg --passphrase '%s' -o '%s' --decrypt '%s'\n".printf(password, tar_file, src_file);
			cmd += "tar xvf '%s' --overwrite --same-permissions -C '%s'\n".printf(tar_file, "/");
			cmd += "rm -f '%s'\n".printf(dst_file);

			log_debug(cmd);
			
			string stdout, stderr;
			int status = execute_command_script_sync(cmd, out stdout, out stderr);
			if (status == 0){
				return true;
			}
			else{
				log_msg(stderr);
			}
		}

		return false;
	}

	// hashing -----------
	
	private string MD5Sum(string path){
		Checksum checksum = new Checksum (ChecksumType.MD5);
		FileStream stream = FileStream.open (path, "rb");

		uint8 fbuf[100];
		size_t size;
		while ((size = stream.read (fbuf)) > 0){
		  checksum.update (fbuf, size);
		}
		
		unowned string digest = checksum.get_string();

		return digest;
	}

	// misc --------------------
	
	public long get_file_count(string path){

		/* Return total count of files and directories */

		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;

		cmd = "find \"%s\" | wc -l".printf(path);
		ret_val = execute_command_script_sync(cmd, out std_out, out std_err);
		return long.parse(std_out);
	}

	public long get_file_size(string path){

		/* Returns size of files and directories in KB*/

		string cmd = "";
		string output = "";

		cmd = "du -s \"%s\"".printf(path);
		output = execute_command_sync_get_output(cmd);
		return long.parse(output.split("\t")[0]);
	}

	public int64 get_file_size_bytes(string file_path){
		try{
			File file = File.parse_name (file_path);
			if (FileUtils.test(file_path, GLib.FileTest.EXISTS)){
				if (FileUtils.test(file_path, GLib.FileTest.IS_REGULAR)
					&& !FileUtils.test(file_path, GLib.FileTest.IS_SYMLINK)){
					return file.query_info("standard::size",0).get_size();
				}
			}
		}
		catch(Error e){
			log_error (e.message);
		}

		return -1;
	}

	public string get_file_size_formatted(string path){

		/* Returns size of files and directories in KB*/

		string cmd = "";
		string output = "";

		cmd = "du -s -h \"%s\"".printf(path);
		output = execute_command_sync_get_output(cmd);
		return output.split("\t")[0].strip();
	}

	public string format_file_size (int64 size, bool binary_units = false){
		int64 KB = binary_units ? 1024 : 1000;
		int64 MB = binary_units ? 1024 * KB : 1000 * KB;
		int64 GB = binary_units ? 1024 * MB : 1000 * MB;

		if (size > GB){
			return "%'0.1f %sB".printf(size/(1.0*GB), (binary_units)?"Gi":"G");
		}
		else if (size > MB){
			return "%'0.1f %sB".printf(size/(1.0*MB), (binary_units)?"Mi":"M");
		}
		else if (size > KB){
			return "%'0.0f %sB".printf(size/(1.0*KB), (binary_units)?"Ki":"K");
		}
		else{
			return "%'0lld B".printf(size);
		}
	}
	
	public int chmod (string file, string permission){

		/* Change file permissions */

		return execute_command_sync ("chmod " + permission + " \"%s\"".printf(file));
	}

	public string resolve_relative_path (string filePath){

		/* Resolve the full path of given file using 'realpath' command */

		string filePath2 = filePath;
		if (filePath2.has_prefix ("~")){
			filePath2 = Environment.get_home_dir () + "/" + filePath2[2:filePath2.length];
		}

		try {
			string output = "";
			Process.spawn_command_line_sync("realpath \"%s\"".printf(filePath2), out output);
			output = output.strip ();
			if (FileUtils.test(output, GLib.FileTest.EXISTS)){
				return output;
			}
		}
		catch(Error e){
	        log_error (e.message);
	    }

	    return filePath2;
	}

	public int rsync (string sourceDirectory, string destDirectory, bool updateExisting, bool deleteExtra){

		/* Sync files with rsync */

		string cmd = "rsync --recursive --perms --chmod=a=rwx";
		cmd += updateExisting ? "" : " --ignore-existing";
		cmd += deleteExtra ? " --delete" : "";
		cmd += " \"%s\"".printf(sourceDirectory + "//");
		cmd += " \"%s\"".printf(destDirectory);
		return execute_command_sync (cmd);
	}
}

namespace TeeJee.JSON{

	using TeeJee.Logging;

	/* Convenience functions for reading and writing JSON files */

	public string json_get_string(Json.Object jobj, string member, string def_value){
		if (jobj.has_member(member)){
			return jobj.get_string_member(member);
		}
		else{
			log_error ("Member not found in JSON object: " + member, false, true);
			return def_value;
		}
	}

	public bool json_get_bool(Json.Object jobj, string member, bool def_value){
		if (jobj.has_member(member)){
			return bool.parse(jobj.get_string_member(member));
		}
		else{
			log_error ("Member not found in JSON object: " + member, false, true);
			return def_value;
		}
	}

	public int json_get_int(Json.Object jobj, string member, int def_value){
		if (jobj.has_member(member)){
			return int.parse(jobj.get_string_member(member));
		}
		else{
			log_error ("Member not found in JSON object: " + member, false, true);
			return def_value;
		}
	}

}

namespace TeeJee.ProcessManagement{
	using TeeJee.Logging;
	using TeeJee.FileSystem;
	using TeeJee.Misc;

	public string TEMP_DIR;

	/* Convenience functions for executing commands and managing processes */

  public static void init_tmp(){
		string std_out, std_err;

		TEMP_DIR = Environment.get_tmp_dir() + "/" + AppShortName;
		create_dir(TEMP_DIR);

		execute_command_script_sync("echo 'ok'",out std_out,out std_err, true);
		if ((std_out == null)||(std_out.strip() != "ok")){
			TEMP_DIR = Environment.get_home_dir() + "/.temp/" + AppShortName;
			execute_command_sync("rm -rf '%s'".printf(TEMP_DIR));
			create_dir(TEMP_DIR);
		}

		//log_debug("TEMP_DIR=" + TEMP_DIR);
	}

	public int execute_command_sync (string cmd){

		/* Executes single command synchronously and returns exit code
		 * Pipes and multiple commands are not supported */

		try {
			int exitCode;
			Process.spawn_command_line_sync(cmd, null, null, out exitCode);
	        return exitCode;
		}
		catch (Error e){
	        log_error (e.message);
	        return -1;
	    }
	}

	public string execute_command_sync_get_output (string cmd){

		/* Executes single command synchronously and returns std_out
		 * Pipes and multiple commands are not supported */

		try {
			int exitCode;
			string std_out;
			Process.spawn_command_line_sync(cmd, out std_out, null, out exitCode);
	        return std_out;
		}
		catch (Error e){
	        log_error (e.message);
	        return "";
	    }
	}

	public bool execute_command_script_async (string cmd){

		/* Creates a temporary bash script with given commands and executes it asynchronously
		 * Return value indicates if script was started successfully */

		try {

			string scriptfile = create_temp_bash_script (cmd);

			string[] argv = new string[1];
			argv[0] = scriptfile;

			Pid child_pid;
			Process.spawn_async_with_pipes(
			    null, //working dir
			    argv, //argv
			    null, //environment
			    SpawnFlags.SEARCH_PATH,
			    null,
			    out child_pid);

			return true;
		}
		catch (Error e){
	        log_error (e.message);
	        return false;
	    }
	}

	public string? create_temp_bash_script (string script_text, bool supress_errors = false){

		/* Creates a temporary bash script with given commands
		 * Returns the script file path */

		var sh = "";
		sh += "#!/bin/bash\n";
		sh += script_text;

		string script_path = get_temp_file_path() + ".sh";

		try{
			//write script file
			var file = File.new_for_path (script_path);
			if (file.query_exists ()) { file.delete (); }
			var file_stream = file.create (FileCreateFlags.REPLACE_DESTINATION);
			var data_stream = new DataOutputStream (file_stream);
			data_stream.put_string (sh);
			data_stream.close();

			// set execute permission
			chmod (script_path, "u+x");

			return script_path;
		}
		catch (Error e) {
			if (!supress_errors){
        log_error (e.message);
			}
    }

		return null;
	}

	public string get_temp_file_path(){

		/* Generates temporary file path */

		return TEMP_DIR + "/" + timestamp2() + (new Rand()).next_int().to_string();
	}

	public int execute_command_script_sync (string script, out string std_out, out string std_err, bool supress_errors = false){

		/* Executes commands synchronously
		 * Returns exit code, output messages and error messages.
		 * Commands are written to a temporary bash script and executed. */

		string path = create_temp_bash_script(script,supress_errors);

		try {

			string[] argv = new string[1];
			argv[0] = path;

			int exit_code;

			Process.spawn_sync (
			    TEMP_DIR, //working dir
			    argv, //argv
			    null, //environment
			    SpawnFlags.SEARCH_PATH,
			    null,   // child_setup
			    out std_out,
			    out std_err,
			    out exit_code
			    );

			return exit_code;
		}
		catch (Error e){
			if (!supress_errors){
        log_error (e.message);
			}
      return -1;
	  }
	}

	public int execute_command_script_sync2 (string script){

		/* Executes commands synchronously
		 * Returns exit code, output messages and error messages.
		 * Commands are written to a temporary bash script and executed. */

		string path = create_temp_bash_script(script);

		try {

			string[] argv = new string[1];
			argv[0] = path;

			int exit_code;

			Process.spawn_sync (
			    TEMP_DIR, //working dir
			    argv, //argv
			    null, //environment
			    SpawnFlags.SEARCH_PATH,
			    null,   // child_setup
			    null,
			    null,
			    out exit_code
			    );

			return exit_code;
		}
		catch (Error e){
	        log_error (e.message);
	        return -1;
	    }
	}

	public bool execute_command_script_in_terminal_sync (string script){

		/* Executes a command script in a terminal window */
		//TODO: Remove this

		try {

			string[] argv = new string[3];
			argv[0] = "x-terminal-emulator";
			argv[1] = "-e";
			argv[2] = script;

			Process.spawn_sync (
			    TEMP_DIR, //working dir
			    argv, //argv
			    null, //environment
			    SpawnFlags.SEARCH_PATH,
			    null   // child_setup
			    );

			return true;
		}
		catch (Error e){
	        log_error (e.message);
	        return false;
	    }
	}

	public int execute_bash_script_fullscreen_sync (string script_file){

		/* Executes a bash script synchronously.
		 * Script is executed in a fullscreen terminal window */

		string path;

		path = get_cmd_path ("xfce4-terminal");
		if ((path != null)&&(path != "")){
			return execute_command_sync ("xfce4-terminal --fullscreen -e \"%s\"".printf(script_file));
		}

		path = get_cmd_path ("gnome-terminal");
		if ((path != null)&&(path != "")){
			return execute_command_sync ("gnome-terminal --full-screen -e \"%s\"".printf(script_file));
		}

		path = get_cmd_path ("xterm");
		if ((path != null)&&(path != "")){
			return execute_command_sync ("xterm --fullscreen -e \"%s\"".printf(script_file));
		}

		//default terminal - unknown, normal window
		path = get_cmd_path ("x-terminal-emulator");
		if ((path != null)&&(path != "")){
			return execute_command_sync ("x-terminal-emulator -e \"%s\"".printf(script_file));
		}

		return -1;
	}

	public int execute_bash_script_sync (string script_file){

		/* Executes a bash script synchronously in the default terminal window */

		string path = get_cmd_path ("x-terminal-emulator");
		if ((path != null)&&(path != "")){
			return execute_command_sync ("x-terminal-emulator -e \"%s\"".printf(script_file));
		}

		return -1;
	}

	public string get_cmd_path (string cmd){

		/* Returns the full path to a command */

		try {
			int exitCode;
			string stdout, stderr;
			Process.spawn_command_line_sync("which " + cmd, out stdout, out stderr, out exitCode);
	        return stdout;
		}
		catch (Error e){
	        log_error (e.message);
	        return "";
	    }
	}

	public int get_pid_by_name (string name){

		/* Get the process ID for a process with given name */

		try{
			string output = "";
			Process.spawn_command_line_sync("pidof \"%s\"".printf(name), out output);
			if (output != null){
				string[] arr = output.split ("\n");
				if (arr.length > 0){
					return int.parse (arr[0]);
				}
			}
		}
		catch (Error e) {
			log_error (e.message);
		}

		return -1;
	}

	public int get_pid_by_command(string cmdline){
		try {
			FileEnumerator enumerator;
			FileInfo info;
			File file = File.parse_name ("/proc");

			enumerator = file.enumerate_children ("standard::name", 0);
			while ((info = enumerator.next_file()) != null) {
				try {
					string io_stat_file_path = "/proc/%s/cmdline".printf(info.get_name());
					var io_stat_file = File.new_for_path(io_stat_file_path);
					if (file.query_exists()){
						var dis = new DataInputStream (io_stat_file.read());

						string line;
						string text = "";
						size_t length;
						while((line = dis.read_until ("\0", out length)) != null){
							text += " " + line;
						}

						if ((text != null) && text.contains(cmdline)){
							return int.parse(info.get_name());
						}
					} //stream closed
				}
				catch(Error e){
				  //log_error (e.message);
				}
			}
		}
		catch(Error e){
		  log_error (e.message);
		}

		return -1;
	}

	public void get_proc_io_stats(int pid, out int64 read_bytes, out int64 write_bytes){
		string io_stat_file_path = "/proc/%d/io".printf(pid);
		var file = File.new_for_path(io_stat_file_path);

		read_bytes = 0;
		write_bytes = 0;

		try {
			if (file.query_exists()){
				var dis = new DataInputStream (file.read());
				string line;
				while ((line = dis.read_line (null)) != null) {
					if(line.has_prefix("rchar:")){
						read_bytes = int64.parse(line.replace("rchar:","").strip());
					}
					else if(line.has_prefix("wchar:")){
						write_bytes = int64.parse(line.replace("wchar:","").strip());
					}
				}
			} //stream closed
		}
		catch(Error e){
			log_error (e.message);
		}
	}

	public bool process_is_running(long pid){

		/* Checks if given process is running */

		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;

		try{
			cmd = "ps --pid %ld".printf(pid);
			Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
		}
		catch (Error e) {
			log_error (e.message);
			return false;
		}

		return (ret_val == 0);
	}

	public int[] get_process_children (Pid parentPid){

		/* Returns the list of child processes spawned by given process */

		string output;

		try {
			Process.spawn_command_line_sync("ps --ppid %d".printf(parentPid), out output);
		}
		catch(Error e){
	        log_error (e.message);
	    }

		int pid;
		int[] procList = {};
		string[] arr;

		foreach (string line in output.split ("\n")){
			arr = line.strip().split (" ");
			if (arr.length < 1) { continue; }

			pid = 0;
			pid = int.parse (arr[0]);

			if (pid != 0){
				procList += pid;
			}
		}
		return procList;
	}

	public void process_quit(Pid process_pid, bool killChildren = true){

		/* Kills specified process and its children (optional) */

		int[] child_pids = get_process_children (process_pid);
		Posix.kill (process_pid, Posix.SIGTERM);

		if (killChildren){
			Pid childPid;
			foreach (long pid in child_pids){
				childPid = (Pid) pid;
				Posix.kill (childPid, Posix.SIGTERM);
			}
		}
	}
	
	public void process_kill(Pid process_pid, bool killChildren = true){

		/* Kills specified process and its children (optional) */

		int[] child_pids = get_process_children (process_pid);
		Posix.kill (process_pid, Posix.SIGKILL);

		if (killChildren){
			Pid childPid;
			foreach (long pid in child_pids){
				childPid = (Pid) pid;
				Posix.kill (childPid, Posix.SIGKILL);
			}
		}
	}

	public int process_pause (Pid procID){

		/* Pause/Freeze a process */

		return execute_command_sync ("kill -STOP %d".printf(procID));
	}

	public int process_resume (Pid procID){

		/* Resume/Un-freeze a process*/

		return execute_command_sync ("kill -CONT %d".printf(procID));
	}

	public void command_kill(string cmd_name, string cmd_to_match, bool exact_match){

		/* Kills a specific command */

		string txt = execute_command_sync_get_output ("ps w -C '%s'".printf(cmd_name));
		//use 'ps ew -C conky' for all users

		string pid = "";
		foreach(string line in txt.split("\n")){
			if ((exact_match && line.has_suffix(" " + cmd_to_match))
			|| (!exact_match && (line.index_of(cmd_to_match) != -1))){
				pid = line.strip().split(" ")[0];
				Posix.kill ((Pid) int.parse(pid), 15);
				log_debug(_("Stopped") + ": [PID=" + pid + "] ");
			}
		}
	}

	public bool process_is_running_by_name(string proc_name){

		/* Checks if given process is running */

		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;

		try{
			cmd = "pgrep -f '%s'".printf(proc_name);
			Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
		}
		catch (Error e) {
			log_error (e.message);
			return false;
		}

		return (ret_val == 0);
	}
	
	public void process_set_priority (Pid procID, int prio){

		/* Set process priority */

		if (Posix.getpriority (Posix.PRIO_PROCESS, procID) != prio)
			Posix.setpriority (Posix.PRIO_PROCESS, procID, prio);
	}

	public int process_get_priority (Pid procID){

		/* Get process priority */

		return Posix.getpriority (Posix.PRIO_PROCESS, procID);
	}

	public void process_set_priority_normal (Pid procID){

		/* Set normal priority for process */

		process_set_priority (procID, 0);
	}

	public void process_set_priority_low (Pid procID){

		/* Set low priority for process */

		process_set_priority (procID, 5);
	}


	public bool user_is_admin (){

		/* Check if current application is running with admin priviledges */

		try{
			// create a process
			string[] argv = { "sleep", "10" };
			Pid procId;
			Process.spawn_async(null, argv, null, SpawnFlags.SEARCH_PATH, null, out procId);

			// try changing the priority
			Posix.setpriority (Posix.PRIO_PROCESS, procId, -5);

			// check if priority was changed successfully
			if (Posix.getpriority (Posix.PRIO_PROCESS, procId) == -5)
				return true;
			else
				return false;
		}
		catch (Error e) {
			log_error (e.message);
			return false;
		}
	}

	public string get_user_login(){
		/*
		Returns Login ID of current user.
		If running as 'sudo' it will return Login ID of the actual user.
		*/

		string cmd = "echo ${SUDO_USER:-$(whoami)}";
		string std_out;
		string std_err;
		int ret_val;
		ret_val = execute_command_script_sync(cmd, out std_out, out std_err);

		string user_name;
		if ((std_out == null) || (std_out.length == 0)){
			user_name = "root";
		}
		else{
			user_name = std_out.strip();
		}

		return user_name;
	}

	public int get_user_id(string user_login){
		/*
		Returns UID of specified user.
		*/

		int uid = -1;
		string cmd = "id %s -u".printf(user_login);
		string txt = execute_command_sync_get_output(cmd);
		if ((txt != null) && (txt.length > 0)){
			uid = int.parse(txt);
		}

		return uid;
	}


	public string get_app_path (){

		/* Get path of current process */

		try{
			return GLib.FileUtils.read_link ("/proc/self/exe");
		}
		catch (Error e){
	        log_error (e.message);
	        return "";
	    }
	}

	public string get_app_dir (){

		/* Get parent directory of current process */

		try{
			return (File.new_for_path (GLib.FileUtils.read_link ("/proc/self/exe"))).get_parent ().get_path ();
		}
		catch (Error e){
	        log_error (e.message);
	        return "";
	    }
	}

}

namespace TeeJee.GtkHelper{

	using Gtk;

	public void gtk_do_events (){

		/* Do pending events */

		while(Gtk.events_pending ())
			Gtk.main_iteration ();
	}

	public void gtk_set_busy (bool busy, Gtk.Window win) {

		/* Show or hide busy cursor on window */

		Gdk.Cursor? cursor = null;

		if (busy){
			cursor = new Gdk.Cursor(Gdk.CursorType.WATCH);
		}
		else{
			cursor = new Gdk.Cursor(Gdk.CursorType.ARROW);
		}

		var window = win.get_window ();

		if (window != null) {
			window.set_cursor (cursor);
		}

		gtk_do_events ();
	}

	public void gtk_messagebox(string title, string message, Gtk.Window? parent_win, bool is_error = false){

		/* Shows a simple message box */

		var type = Gtk.MessageType.INFO;
		if (is_error){
			type = Gtk.MessageType.ERROR;
		}
		else{
			type = Gtk.MessageType.INFO;
		}

		/*var dlg = new Gtk.MessageDialog.with_markup(null, Gtk.DialogFlags.MODAL, type, Gtk.ButtonsType.OK, message);
		dlg.title = title;
		dlg.set_default_size (200, -1);
		if (parent_win != null){
			dlg.set_transient_for(parent_win);
			dlg.set_modal(true);
		}
		dlg.run();
		dlg.destroy();*/

		var dlg = new CustomMessageDialog(title,message,type,parent_win);
		dlg.run();
	}

	public bool gtk_combobox_set_value (ComboBox combo, int index, string val){

		/* Conveniance function to set combobox value */

		TreeIter iter;
		string comboVal;
		TreeModel model = (TreeModel) combo.model;

		bool iterExists = model.get_iter_first (out iter);
		while (iterExists){
			model.get(iter, 1, out comboVal);
			if (comboVal == val){
				combo.set_active_iter(iter);
				return true;
			}
			iterExists = model.iter_next (ref iter);
		}

		return false;
	}

	public string gtk_combobox_get_value (ComboBox combo, int index, string default_value){

		/* Conveniance function to get combobox value */

		if ((combo.model == null) || (combo.active < 0)) { return default_value; }

		TreeIter iter;
		string val = "";
		combo.get_active_iter (out iter);
		TreeModel model = (TreeModel) combo.model;
		model.get(iter, index, out val);

		return val;
	}
	
	public int gtk_combobox_get_value_enum (ComboBox combo, int index, int default_value){

		/* Conveniance function to get combobox value */

		if ((combo.model == null) || (combo.active < 0)) { return default_value; }

		TreeIter iter;
		int val;
		combo.get_active_iter (out iter);
		TreeModel model = (TreeModel) combo.model;
		model.get(iter, index, out val);

		return val;
	}

	public class CellRendererProgress2 : Gtk.CellRendererProgress{
		public override void render (Cairo.Context cr, Gtk.Widget widget, Gdk.Rectangle background_area, Gdk.Rectangle cell_area, Gtk.CellRendererState flags) {
			if (text == "--")
				return;

			int diff = (int) ((cell_area.height - height)/2);

			// Apply the new height into the bar, and center vertically:
			Gdk.Rectangle new_area = Gdk.Rectangle() ;
			new_area.x = cell_area.x;
			new_area.y = cell_area.y + diff;
			new_area.width = width - 5;
			new_area.height = height;

			base.render(cr, widget, background_area, new_area, flags);
		}
	}

	public Gdk.Pixbuf? get_app_icon(int icon_size, string format = ".png"){
		var img_icon = get_shared_icon(AppShortName, AppShortName + format,icon_size,"pixmaps");
		if (img_icon != null){
			return img_icon.pixbuf;
		}
		else{
			return null;
		}
	}

	public Gtk.Image? get_shared_icon(string icon_name, string fallback_icon_file_name, int icon_size, string icon_directory = AppShortName + "/images"){
		Gdk.Pixbuf pix_icon = null;
		Gtk.Image img_icon = null;

		try {
			Gtk.IconTheme icon_theme = Gtk.IconTheme.get_default();
			pix_icon = icon_theme.load_icon (icon_name, icon_size, 0);
		} catch (Error e) {
			//log_error (e.message);
		}

		string fallback_icon_file_path = "/usr/share/%s/%s".printf(icon_directory, fallback_icon_file_name);

		if (pix_icon == null){
			try {
				pix_icon = new Gdk.Pixbuf.from_file_at_size (fallback_icon_file_path, icon_size, icon_size);
			} catch (Error e) {
				log_error (e.message);
			}
		}

		if (pix_icon == null){
			log_error (_("Missing Icon") + ": '%s', '%s'".printf(icon_name, fallback_icon_file_path));
		}
		else{
			img_icon = new Gtk.Image.from_pixbuf(pix_icon);
		}

		return img_icon;
	}

	public int gtk_treeview_model_count(TreeModel model){
		int count = 0;
		TreeIter iter;
		if (model.get_iter_first(out iter)){
			count++;
			while(model.iter_next(ref iter)){
				count++;
			}
		}
		return count;
	}
}

namespace TeeJee.Multimedia{

	using TeeJee.Logging;

	/* Functions for working with audio/video files */

	public long get_file_duration(string filePath){

		/* Returns the duration of an audio/video file using MediaInfo */

		string output = "0";

		try {
			Process.spawn_command_line_sync("mediainfo \"--Inform=General;%Duration%\" \"" + filePath + "\"", out output);
		}
		catch(Error e){
	        log_error (e.message);
	    }

		return long.parse(output);
	}

	public string get_file_crop_params (string filePath){

		/* Returns cropping parameters for a video file using avconv */

		string output = "";
		string error = "";

		try {
			Process.spawn_command_line_sync("avconv -i \"%s\" -vf cropdetect=30 -ss 5 -t 5 -f matroska -an -y /dev/null".printf(filePath), out output, out error);
		}
		catch(Error e){
	        log_error (e.message);
	    }

	    int w=0,h=0,x=10000,y=10000;
		int num=0;
		string key,val;
	    string[] arr;

	    foreach (string line in error.split ("\n")){
			if (line == null) { continue; }
			if (line.index_of ("crop=") == -1) { continue; }

			foreach (string part in line.split (" ")){
				if (part == null || part.length == 0) { continue; }

				arr = part.split (":");
				if (arr.length != 2) { continue; }

				key = arr[0].strip ();
				val = arr[1].strip ();

				switch (key){
					case "x":
						num = int.parse (arr[1]);
						if (num < x) { x = num; }
						break;
					case "y":
						num = int.parse (arr[1]);
						if (num < y) { y = num; }
						break;
					case "w":
						num = int.parse (arr[1]);
						if (num > w) { w = num; }
						break;
					case "h":
						num = int.parse (arr[1]);
						if (num > h) { h = num; }
						break;
				}
			}
		}

		if (x == 10000 || y == 10000)
			return "%i:%i:%i:%i".printf(0,0,0,0);
		else
			return "%i:%i:%i:%i".printf(w,h,x,y);
	}

	public string get_mediainfo (string filePath){

		/* Returns the multimedia properties of an audio/video file using MediaInfo */

		string output = "";

		try {
			Process.spawn_command_line_sync("mediainfo \"%s\"".printf(filePath), out output);
		}
		catch(Error e){
	        log_error (e.message);
	    }

		return output;
	}



}

namespace TeeJee.System{

	using TeeJee.ProcessManagement;
	using TeeJee.Logging;

	public double get_system_uptime_seconds(){

		/* Returns the system up-time in seconds */

		string cmd = "";
		string std_out;
		string std_err;
		int ret_val;

		try{
			cmd = "cat /proc/uptime";
			Process.spawn_command_line_sync(cmd, out std_out, out std_err, out ret_val);
			string uptime = std_out.split(" ")[0];
			double secs = double.parse(uptime);
			return secs;
		}
		catch(Error e){
			log_error (e.message);
			return 0;
		}
	}

	public string get_desktop_name(){

		/* Return the names of the current Desktop environment */

		int pid = -1;

		pid = get_pid_by_name("cinnamon");
		if (pid > 0){
			return "Cinnamon";
		}

		pid = get_pid_by_name("xfdesktop");
		if (pid > 0){
			return "Xfce";
		}

		pid = get_pid_by_name("lxsession");
		if (pid > 0){
			return "LXDE";
		}

		pid = get_pid_by_name("gnome-shell");
		if (pid > 0){
			return "Gnome";
		}

		pid = get_pid_by_name("wingpanel");
		if (pid > 0){
			return "Elementary";
		}

		pid = get_pid_by_name("unity-panel-service");
		if (pid > 0){
			return "Unity";
		}

		pid = get_pid_by_name("plasma-desktop");
		if (pid > 0){
			return "KDE";
		}

		return "Unknown";
	}

	public Gee.ArrayList<string> list_dir_names(string path){
		var list = new Gee.ArrayList<string>();
		
		try
		{
			File f_home = File.new_for_path (path);
			FileEnumerator enumerator = f_home.enumerate_children ("%s".printf(FileAttribute.STANDARD_NAME), 0);
			FileInfo file;
			while ((file = enumerator.next_file ()) != null) {
				string name = file.get_name();
				//string item = path + "/" + name;
				list.add(name);
			}
		}
		catch (Error e) {
			log_error (e.message);
		}

		//sort the list
		CompareDataFunc<string> entry_compare = (a, b) => {
			return strcmp(a,b);
		};
		list.sort((owned) entry_compare);

		return list;
	}
	
	public bool check_internet_connectivity(){
		int exit_code = -1;
		string std_err;
		string std_out;

		try {
			string cmd = "ping -c 1 google.com";
			Process.spawn_command_line_sync(cmd, out std_out, out std_err, out exit_code);
		}
		catch (Error e){
	        log_error (e.message);
	    }

	    return (exit_code == 0);
	}
	
	public bool shutdown (){

		/* Shutdown the system immediately */

		try{
			string[] argv = { "shutdown", "-h", "now" };
			Pid procId;
			Process.spawn_async(null, argv, null, SpawnFlags.SEARCH_PATH, null, out procId);
			return true;
		}
		catch (Error e) {
			log_error (e.message);
			return false;
		}
	}

	public bool xdg_open (string file){
		string path;
		path = get_cmd_path ("xdg-open");
		if ((path != null)&&(path != "")){
			return execute_command_script_async ("xdg-open \"" + file + "\"");
		}
		return false;
	}

	public bool exo_open_folder (string dir_path, bool xdg_open_try_first = true){

		/* Tries to open the given directory in a file manager */

		/*
		xdg-open is a desktop-independent tool for configuring the default applications of a user.
		Inside a desktop environment (e.g. GNOME, KDE, Xfce), xdg-open simply passes the arguments
		to that desktop environment's file-opener application (gvfs-open, kde-open, exo-open, respectively).
		We will first try using xdg-open and then check for specific file managers if it fails.
		*/

		string path;

		if (xdg_open_try_first){
			//try using xdg-open
			path = get_cmd_path ("xdg-open");
			if ((path != null)&&(path != "")){
				return execute_command_script_async ("xdg-open \"" + dir_path + "\"");
			}
		}

		path = get_cmd_path ("nemo");
		if ((path != null)&&(path != "")){
			return execute_command_script_async ("nemo \"" + dir_path + "\"");
		}

		path = get_cmd_path ("nautilus");
		if ((path != null)&&(path != "")){
			return execute_command_script_async ("nautilus \"" + dir_path + "\"");
		}

		path = get_cmd_path ("thunar");
		if ((path != null)&&(path != "")){
			return execute_command_script_async ("thunar \"" + dir_path + "\"");
		}

		path = get_cmd_path ("pantheon-files");
		if ((path != null)&&(path != "")){
			return execute_command_script_async ("pantheon-files \"" + dir_path + "\"");
		}

		path = get_cmd_path ("marlin");
		if ((path != null)&&(path != "")){
			return execute_command_script_async ("marlin \"" + dir_path + "\"");
		}

		if (xdg_open_try_first == false){
			//try using xdg-open
			path = get_cmd_path ("xdg-open");
			if ((path != null)&&(path != "")){
				return execute_command_script_async ("xdg-open \"" + dir_path + "\"");
			}
		}

		return false;
	}

	public bool exo_open_textfile (string txt){

		/* Tries to open the given text file in a text editor */

		string path;

		path = get_cmd_path ("exo-open");
		if ((path != null)&&(path != "")){
			return execute_command_script_async ("exo-open \"" + txt + "\"");
		}

		path = get_cmd_path ("gedit");
		if ((path != null)&&(path != "")){
			return execute_command_script_async ("gedit --new-document \"" + txt + "\"");
		}

		return false;
	}

	public bool exo_open_url (string url){

		/* Tries to open the given text file in a text editor */

		string path;

		path = get_cmd_path ("exo-open");
		if ((path != null)&&(path != "")){
			return execute_command_script_async ("exo-open \"" + url + "\"");
		}

		path = get_cmd_path ("firefox");
		if ((path != null)&&(path != "")){
			return execute_command_script_async ("firefox \"" + url + "\"");
		}

		path = get_cmd_path ("chromium-browser");
		if ((path != null)&&(path != "")){
			return execute_command_script_async ("chromium-browser \"" + url + "\"");
		}

		return false;
	}

	public GLib.Timer timer_start(){
		var timer = new GLib.Timer();
		timer.start();
		return timer;
	}

	public ulong timer_elapsed(GLib.Timer timer){
		ulong microseconds;
		double seconds;
		seconds = timer.elapsed (out microseconds);
		return microseconds;
	}

	public void sleep(int milliseconds){
		Thread.usleep ((ulong) milliseconds * 1000);
	}

	public string timer_elapsed_string(GLib.Timer timer, bool stop = true){
		ulong microseconds;
		double seconds;
		seconds = timer.elapsed (out microseconds);
		if (stop){
			timer.stop();
		}
		return "%.0f ms".printf((seconds * 1000 ) + microseconds/1000);
	}

	public void timer_elapsed_print(GLib.Timer timer, bool stop = true){
		ulong microseconds;
		double seconds;
		seconds = timer.elapsed (out microseconds);
		if (stop){
			timer.stop();
		}
		log_msg("%s %lu\n".printf(seconds.to_string(), microseconds));
	}

	public string[] array_concat(string[] a, string[] b){
		string[] c = {};
		foreach(string str in a){ c += str; }
		foreach(string str in b){ c += str; }
		return c;
	}
	
	private DateTime dt_last_notification = null;
	private const int NOTIFICATION_INTERVAL = 3;

	public int notify_send (string title, string message, int durationMillis, string urgency, string dialog_type = "info"){

		/* Displays notification bubble on the desktop */

		int retVal = 0;

		switch (dialog_type){
			case "error":
			case "info":
			case "warning":
				//ok
				break;
			default:
				dialog_type = "info";
				break;
		}

		long seconds = 9999;
		if (dt_last_notification != null){
			DateTime dt_end = new DateTime.now_local();
			TimeSpan elapsed = dt_end.difference(dt_last_notification);
			seconds = (long)(elapsed * 1.0 / TimeSpan.SECOND);
		}

		if (seconds > NOTIFICATION_INTERVAL){
			string s = "notify-send -t %d -u %s -i %s \"%s\" \"%s\"".printf(durationMillis, urgency, "gtk-dialog-" + dialog_type, title, message);
			retVal = execute_command_sync (s);
			dt_last_notification = new DateTime.now_local();
		}

		return retVal;
	}

	public bool set_directory_ownership(string dir_name, string login_name){
		try {
			string cmd = "chown %s -R %s".printf(login_name, dir_name);
			int exit_code;
			Process.spawn_command_line_sync(cmd, null, null, out exit_code);

			if (exit_code == 0){
				log_msg(_("Set owner: %s, dir: %s").printf(login_name, dir_name));
				return true;
			}
			else{
				log_error(_("Failed to set ownership") + ": %s, %s".printf(login_name, dir_name));
				return false;
			}
		}
		catch (Error e){
			log_error (e.message);
			return false;
		}
	}

	public class ProcStats{
		public double user = 0;
		public double nice = 0;
		public double system = 0;
		public double idle = 0;
		public double iowait = 0;

		public double user_delta = 0;
		public double nice_delta = 0;
		public double system_delta = 0;
		public double idle_delta = 0;
		public double iowait_delta = 0;

		public double usage_percent = 0;

		public static ProcStats stat_prev = null;

		public ProcStats(string line){
			string[] arr = line.split(" ");
			int col = 0;
			if (arr[col++] == "cpu"){
				if (arr[col].length == 0){ col++; };

				user = double.parse(arr[col++]);
				nice = double.parse(arr[col++]);
				system = double.parse(arr[col++]);
				idle = double.parse(arr[col++]);
				iowait = double.parse(arr[col++]);

				if (ProcStats.stat_prev != null){
					user_delta = user - ProcStats.stat_prev.user;
					nice_delta = nice - ProcStats.stat_prev.nice;
					system_delta = system - ProcStats.stat_prev.system;
					idle_delta = idle - ProcStats.stat_prev.idle;
					iowait_delta = iowait - ProcStats.stat_prev.iowait;

					usage_percent = (user_delta + nice_delta + system_delta) * 100 / (user_delta + nice_delta + system_delta + idle_delta);
				}
				else{
					usage_percent = 0;

				}

				ProcStats.stat_prev = this;
			}
		}
		
		//returns 0 when it is called first time
		public static double get_cpu_usage(){
			string txt = read_file("/proc/stat");
			foreach(string line in txt.split("\n")){
				string[] arr = line.split(" ");
				if (arr[0] == "cpu"){
					ProcStats stat = new ProcStats(line);
					return stat.usage_percent;
				}
			}
			return 0;
		}
	}
}

namespace TeeJee.Misc {

	/* Various utility functions */

	using Gtk;
	using TeeJee.Logging;
	using TeeJee.FileSystem;
	using TeeJee.ProcessManagement;

	public class DistInfo : GLib.Object{

		/* Class for storing information about linux distribution */

		public string dist_id = "";
		public string description = "";
		public string release = "";
		public string codename = "";

		public DistInfo(){
			dist_id = "";
			description = "";
			release = "";
			codename = "";
		}

		public string full_name(){
			if (dist_id == ""){
				return "";
			}
			else{
				string val = "";
				val += dist_id;
				val += (release.length > 0) ? " " + release : "";
				val += (codename.length > 0) ? " (" + codename + ")" : "";
				return val;
			}
		}

		public static DistInfo get_dist_info(string root_path){

			/* Returns information about the Linux distribution
			 * installed at the given root path */

			DistInfo info = new DistInfo();

			string dist_file = root_path + "/etc/lsb-release";
			var f = File.new_for_path(dist_file);
			if (f.query_exists()){

				/*
					DISTRIB_ID=Ubuntu
					DISTRIB_RELEASE=13.04
					DISTRIB_CODENAME=raring
					DISTRIB_DESCRIPTION="Ubuntu 13.04"
				*/

				foreach(string line in read_file(dist_file).split("\n")){

					if (line.split("=").length != 2){ continue; }

					string key = line.split("=")[0].strip();
					string val = line.split("=")[1].strip();

					if (val.has_prefix("\"")){
						val = val[1:val.length];
					}

					if (val.has_suffix("\"")){
						val = val[0:val.length-1];
					}

					switch (key){
						case "DISTRIB_ID":
							info.dist_id = val;
							break;
						case "DISTRIB_RELEASE":
							info.release = val;
							break;
						case "DISTRIB_CODENAME":
							info.codename = val;
							break;
						case "DISTRIB_DESCRIPTION":
							info.description = val;
							break;
					}
				}
			}
			else{

				dist_file = root_path + "/etc/os-release";
				f = File.new_for_path(dist_file);
				if (f.query_exists()){

					/*
						NAME="Ubuntu"
						VERSION="13.04, Raring Ringtail"
						ID=ubuntu
						ID_LIKE=debian
						PRETTY_NAME="Ubuntu 13.04"
						VERSION_ID="13.04"
						HOME_URL="http://www.ubuntu.com/"
						SUPPORT_URL="http://help.ubuntu.com/"
						BUG_REPORT_URL="http://bugs.launchpad.net/ubuntu/"
					*/

					foreach(string line in read_file(dist_file).split("\n")){

						if (line.split("=").length != 2){ continue; }

						string key = line.split("=")[0].strip();
						string val = line.split("=")[1].strip();

						switch (key){
							case "ID":
								info.dist_id = val;
								break;
							case "VERSION_ID":
								info.release = val;
								break;
							//case "DISTRIB_CODENAME":
								//info.codename = val;
								//break;
							case "PRETTY_NAME":
								info.description = val;
								break;
						}
					}
				}
			}

			return info;
		}

	}

	public static Gdk.RGBA hex_to_rgba (string hex_color){

		/* Converts the color in hex to RGBA */

		string hex = hex_color.strip().down();
		if (hex.has_prefix("#") == false){
			hex = "#" + hex;
		}

		Gdk.RGBA color = Gdk.RGBA();
		if(color.parse(hex) == false){
			color.parse("#000000");
		}
		color.alpha = 255;

		return color;
	}

	public static string rgba_to_hex (Gdk.RGBA color, bool alpha = false, bool prefix_hash = true){

		/* Converts the color in RGBA to hex */

		string hex = "";

		if (alpha){
			hex = "%02x%02x%02x%02x".printf((uint)(Math.round(color.red*255)),
									(uint)(Math.round(color.green*255)),
									(uint)(Math.round(color.blue*255)),
									(uint)(Math.round(color.alpha*255)))
									.up();
		}
		else {
			hex = "%02x%02x%02x".printf((uint)(Math.round(color.red*255)),
									(uint)(Math.round(color.green*255)),
									(uint)(Math.round(color.blue*255)))
									.up();
		}

		if (prefix_hash){
			hex = "#" + hex;
		}

		return hex;
	}

	public string timestamp2 (){

		/* Returns a numeric timestamp string */

		return "%ld".printf((long) time_t ());
	}

	public string timestamp (){

		/* Returns a formatted timestamp string */

		Time t = Time.local (time_t ());
		return t.format ("%H:%M:%S");
	}

	public string timestamp3 (){

		/* Returns a formatted timestamp string */

		Time t = Time.local (time_t ());
		return t.format ("%Y-%d-%m_%H-%M-%S");
	}

	public string format_duration (long millis){

		/* Converts time in milliseconds to format '00:00:00.0' */

	    double time = millis / 1000.0; // time in seconds

	    double hr = Math.floor(time / (60.0 * 60));
	    time = time - (hr * 60 * 60);
	    double min = Math.floor(time / 60.0);
	    time = time - (min * 60);
	    double sec = Math.floor(time);

        return "%02.0lf:%02.0lf:%02.0lf".printf (hr, min, sec);
	}

	public double parse_time (string time){

		/* Converts time in format '00:00:00.0' to milliseconds */

		string[] arr = time.split (":");
		double millis = 0;
		if (arr.length >= 3){
			millis += double.parse(arr[0]) * 60 * 60;
			millis += double.parse(arr[1]) * 60;
			millis += double.parse(arr[2]);
		}
		return millis;
	}

	public string escape_html(string html){
		return html
		.replace("&","&amp;")
		.replace("\"","&quot;")
		//.replace(" ","&nbsp;") //pango markup throws an error with &nbsp;
		.replace("<","&lt;")
		.replace(">","&gt;")
		;
	}

	public string unescape_html(string html){
		return html
		.replace("&amp;","&")
		.replace("&quot;","\"")
		//.replace("&nbsp;"," ") //pango markup throws an error with &nbsp;
		.replace("&lt;","<")
		.replace("&gt;",">")
		;
	}

	public DateTime datetime_from_string (string date_time_string){

		/* Converts date time string to DateTime
		 * 
		 * Supported inputs:
		 * 'yyyy-MM-dd'
		 * 'yyyy-MM-dd HH'
		 * 'yyyy-MM-dd HH:mm'
		 * 'yyyy-MM-dd HH:mm:ss'
		 * */

		string[] arr = date_time_string.replace(":"," ").replace("-"," ").strip().split(" ");

		int year  = (arr.length >= 3) ? int.parse(arr[0]) : 0;
		int month = (arr.length >= 3) ? int.parse(arr[1]) : 0;
		int day   = (arr.length >= 3) ? int.parse(arr[2]) : 0;
		int hour  = (arr.length >= 4) ? int.parse(arr[3]) : 0;
		int min   = (arr.length >= 5) ? int.parse(arr[4]) : 0;
		int sec   = (arr.length >= 6) ? int.parse(arr[5]) : 0;

		return new DateTime.utc(year,month,day,hour,min,sec);
	}
	
}
