require 'activerecord'
require 'yaml'

namespace :openid do
  config = YAML.load_file(File.expand_path("application.yml", RAILS_ROOT + "/config"))
  namespace :server do
    openid_stub_server_pid = if config["server_type"] = "mongrel"
      File.expand_path("mongrel.pid", RAILS_ROOT + "/tmp/pids")
    end

    def server_running?(pid_path)
      return false unless File.exist?(pid_path)
      pid = Integer(File.read(pid_path))
      begin
        Process.getpgid(pid)
      rescue
        File.unlink(pid_path)
        return false
      end
    end

    desc "start openid stub server"
    task :start => :setup do
      if server_running?(openid_stub_server_pid)
        $stderr.puts "openid stub server is already running."
      else
        $stderr.puts "Starting up openid stub server."
        system("ruby", "script/server", "--port", String(config["port"]),
          "--binding=#{config['binding']}",
          "--environment=#{config['environment']}", "--daemon")
      end
    end

    desc "stop openid stub server"
    task :stop do
      unless File.exist?(openid_stub_server_pid)
        $stderr.puts "No server running."
      else
        $stderr.puts "Shutting down openid stub server."
        system("kill", "-s", "TERM", File.read(openid_stub_server_pid).strip)
      end
    end

    desc "reload openid stub server"
    task :restart do
      unless File.exist?(openid_stub_server_pid)
        $stderr.puts "No server running."
      else
        $stderr.puts "Reloading down openid stub server."
        system("kill", "-s", "USR2", File.read(openid_stub_server_pid))
      end
    end

    desc "setup database w/ specified environment in config/application.yml"
    task :setup => :environment do
      db_dir = "#{RAILS_ROOT}/db"
      Dir.mkdir db_dir unless File.exist?(db_dir)
      log_dir = "#{RAILS_ROOT}/log"
      Dir.mkdir log_dir unless File.exist?(log_dir)
      env = config["environment"]
      dbconfig = ActiveRecord::Base.configurations[RAILS_ENV]
      if dbconfig['adapter'] == 'sqlite3'
        unless File.exist?(File.expand_path(dbconfig['database'], db_dir))
          ActiveRecord::Base.establish_connection(env.to_sym)
          Rake::Task["db:migrate"].invoke
        end
      end
    end
  end
end
