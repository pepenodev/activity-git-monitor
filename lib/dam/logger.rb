require "logger"
require "fileutils"

module Dam
  module Log
    LOG_PATH = File.expand_path("~/.dam/dam.log")

    def self.setup(verbose: false)
      FileUtils.mkdir_p(File.dirname(LOG_PATH))

      @file_logger = Logger.new(LOG_PATH, "daily")
      @file_logger.level = Logger::DEBUG

      @console_logger = Logger.new($stdout)
      @console_logger.level = verbose ? Logger::DEBUG : Logger::INFO

      @console_logger.formatter = proc do |severity, time, _, msg|
        color = color_for(severity)
        reset = "\e[0m"
        "#{color}[#{time.strftime('%H:%M:%S')}] #{severity.ljust(5)} #{msg}#{reset}\n"
      end

      @file_logger.formatter = proc do |severity, time, _, msg|
        "[#{time.strftime('%Y-%m-%d %H:%M:%S')}] #{severity.ljust(5)} #{msg}\n"
      end
    end

    def self.debug(msg) = log(Logger::DEBUG, msg)
    def self.info(msg)  = log(Logger::INFO,  msg)
    def self.warn(msg)  = log(Logger::WARN,  msg)
    def self.error(msg) = log(Logger::ERROR, msg)

    private

    def self.log(level, msg)
      setup unless @console_logger  
      @console_logger.add(level, msg)
      @file_logger.add(level, msg)
    end

    def self.color_for(severity)
      case severity
      when "DEBUG" then "\e[90m"   
      when "INFO"  then "\e[36m"   
      when "WARN"  then "\e[33m"   
      when "ERROR" then "\e[31m"   
      else "\e[0m"
      end
    end
  end
end