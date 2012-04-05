require 'find'

class ErlangModule
  attr_reader :mod
  def initialize(mod)
    @mod = mod
    @functions = []
  end
  def functions()
    @functions.sort
  end
  def import_function(func)
    unless @functions.include?(func)
      @functions << func
    end
  end
  def to_s
    "#{@mod}, #{@functions}"
  end
end

class Export
  attr_reader :name, :arity
  include Comparable
  def initialize(name, arity)
    @name = name
    @arity = arity
  end
  def to_s
    "#{@name}/#{@arity}"
  end
  def is_otp_export
    otp_exports = ["handle_call", "handle_cast", "start_link",
    "handle_info", "code_change", "start", "stop" ]
    otp_exports.include? @name
  end
  def <=>(other)
    @name <=> other.name
  end
end

def collect_imports(file_path, mod, func, imports, include_otp)
  imports[file_path] ||= {}
  
  if not include_otp and is_otp_module(mod)
    return
  end

  this_mod = File.basename(file_path, '.*')

  if this_mod == mod
    # If a module uses its own function, it's not an export
    return
  end

  imports[file_path][mod] ||= ErlangModule.new(mod)
  imports[file_path][mod].import_function(func)
end

def find_imports(params = {})
  mfa_call_regex = /\b([a-zA-Z][a-zA-Z0-9_]*):([a-z_][a-z0-9_]*)/
  rpc_call_regex = /\brpc:call\(.*,\b*([a-zA-Z][a-zA-Z0-9_]*)\b*,\b*([a-z_][a-z0-9_]*)/

  directory = params[:directory] || "."
  include_otp = params[:include_otp]

  imports = {}

  Find.find(directory) do |file_path|
    file_name = File.basename(file_path)
    if file_name =~ /\.erl$/
      IO.foreach(file_path) do |line|
        if not line =~ /^\b*%/
          line.scan(mfa_call_regex).each do |mod, func|
            collect_imports(file_path, mod, func, imports, include_otp)
          end
          line.scan(rpc_call_regex).each do |mod, func|
            collect_imports(file_path, mod, func, imports, include_otp)
          end
        end
      end
    end
  end
  imports
end

def find_exports(params = {})
  directory = params[:directory] || "."
  exports = {}
  Find.find('.') do |file_path|
    file_name = File.basename(file_path)
    if file_name =~ /\.erl$/
      IO.foreach(file_path) do |line|
        line.scan(/([a-z_]+)\/([0-9]+)/).each do |name, arity|
          exports[file_path] ||= []
          exports[file_path] << Export.new(name, arity.to_i)
        end
      end
      exports[file_path].sort! if exports[file_path]
    end
  end

  exports
end

def is_otp_module(module_name) 

  otp_module_names = [ "erlang", "lists", "gb_trees", "proplists",
  "gen_server", "io", "ets", "string", "io_lib", "array", "base64",
  "beam_lib", "binary", "c", "calendar", "dets", "dict", "digraph",
  "epp", "digraph_utils", "erl_eval", "erl_expand_records",
  "erl_id_trans", "erl_internal", "erl_lint", "erl_parse", "erl_pp",
  "erl_scan", "erl_tar", "file_sorter" "filelib" "filename",
  "gb_sets", "gen_event", "gen_fsm", "lib", "log_mf_h", "math",
  "ms_transform", "orddict", "ordsets", "pg", "pool", "proc_lib",
  "qlc", "queue", "random", "re", "sets", "shell", "slave", "sofs",
  "supervisor", "supervisor_bridge", "sys", "timer", "unicode",
  "win32reg", "zip" ]

  otp_module_names.include?(module_name) 
end
