require "tty-table"
require "pastel"
require "date"

class String
  def ljust_with_ansi(width)
    plain_len = gsub(/\e\[[\d;]*[A-Za-z]/, "").length
    self + " " * [width - plain_len, 0].max
  end
end

module Dam
  class Reporter
    HEATMAP_DAYS = 30
    MIN_W = 64

    HEAT_LEVELS = [
      { min: 0,    char: "·", color: :dim   },
      { min: 1,    char: "░", color: :cyan  },
      { min: 1800, char: "▒", color: :cyan  },
      { min: 3600, char: "▓", color: :green },
      { min: 7200, char: "█", color: :green }
    ].freeze

    def initialize(since:)
      @since  = since
      @db     = Database.instance
      @pastel = Pastel.new
      @w      = MIN_W
    end

    def print_summary(title:)
      rows  = @db.aggregate_by_project(since: @since)
      total = rows.sum { |r| r["total_seconds"].to_i }

      rendered = nil

      unless rows.empty?
        table = TTY::Table.new(
          header: ["Project", "Branch", "Sessions", "Time"],
          rows: rows.map do |r|
            [
              @pastel.cyan(r["project"]),
              @pastel.dim(r["branch"]),
              r["session_count"].to_s,
              @pastel.green(format_duration(r["total_seconds"].to_i))
            ]
          end
        )
        rendered = table.render(:unicode, padding: [0, 1])
        table_w  = rendered.each_line.map { |l| strip_ansi(l.chomp).length }.max
        @w       = [@w, table_w].max
      end

      puts d("╠") + "─" * @w + d("╣")

      if rendered
        rendered.each_line do |line|
          line      = line.chomp
          plain_len = strip_ansi(line).length
          padding   = [@w - plain_len, 0].max
          puts d("║") + line + " " * padding + d("║")
        end
      else
        msg = "  No activity for this period."
        puts d("║") + msg + " " * [@w - msg.length, 0].max + d("║")
      end

      puts d("╠") + "─" * @w + d("╣")

      total_plain = "Total: #{format_duration(total)}"
      total_str   = "Total: #{@pastel.bold.green(format_duration(total))}"
      gap = @w - 2 - title.length - total_plain.length - 2
      gap = [gap, 1].max

      puts d("║") + "  " + @pastel.dim(title) + " " * gap + total_str + "  " + d("║")
      puts d("╚") + "═" * @w + d("╝")
      puts ""
    end

    def print_heatmap
      since  = Date.today - HEATMAP_DAYS
      data   = @db.activity_by_day(since: Time.new(since.year, since.month, since.day))
      by_day = data.each_with_object({}) { |r, h| h[r["day"]] = r["total_seconds"].to_i }

      title     = "activity-git"
      title_pad = (@w - title.length) / 2

      puts ""
      puts d("╔") + "═" * @w + d("╗")
      puts d("║") + " " * title_pad + @pastel.bold.white(title) +
           " " * [@w - title_pad - title.length, 0].max + d("║")
      puts d("╠") + "─" * @w + d("╣")

      label = "  activity — last #{HEATMAP_DAYS} days"
      puts d("║") + @pastel.dim(label) + " " * [@w - label.length, 0].max + d("║")

      days_header = "  Mo Tu We Th Fr Sa Su"
      puts d("║") + @pastel.dim(days_header) + " " * [@w - days_header.length, 0].max + d("║")
      puts d("║") + " " * @w + d("║")

      start_date   = since - ((since.wday + 6) % 7)
      current_date = start_date
      weeks = []
      week  = []

      until current_date > Date.today
        week << current_date
        if week.size == 7
          weeks << week
          week = []
        end
        current_date += 1
      end
      week << nil while week.size < 7
      weeks << week unless week.all?(&:nil?)

      weeks.each do |w|
        colored = "  "
        plain   = "  "
        w.each do |day|
          if day.nil? || day > Date.today || day < since
            colored += "   "
            plain   += "   "
          else
            seconds = by_day[day.to_s] || 0
            level   = heat_level(seconds)
            colored += @pastel.send(level[:color], level[:char]) + "  "
            plain   += level[:char] + "  "
          end
        end
        puts d("║") + colored + " " * [@w - plain.length, 0].max + d("║")
      end

      puts d("║") + " " * @w + d("║")

      legend = "  · none  ░ <30m  ▒ <1h  ▓ <2h  █ 2h+"
      puts d("║") + @pastel.dim(legend) + " " * [@w - legend.length, 0].max + d("║")
    end

    def calculate_width
      rows = @db.aggregate_by_project(since: @since)
      return if rows.empty?

      table = TTY::Table.new(
        header: ["Project", "Branch", "Sessions", "Time"],
        rows: rows.map do |r|
          [r["project"], r["branch"], r["session_count"].to_s,
          format_duration(r["total_seconds"].to_i)]
        end
      )
      rendered = table.render(:unicode, padding: [0, 1])
      table_w  = rendered.each_line.map { |l| strip_ansi(l.chomp).length }.max
      @w       = [@w, table_w].max
    end

    private

    def d(char)
      @pastel.dim(char)
    end

    def strip_ansi(str)
      str.gsub(/\e\[[\d;]*[A-Za-z]/, "")
    end

    def heat_level(seconds)
      HEAT_LEVELS.reverse.find { |l| seconds >= l[:min] }
    end

    def format_duration(seconds)
      h = seconds / 3600
      m = (seconds % 3600) / 60
      s = seconds % 60
      if h > 0
        "#{h}h #{m}m"
      elsif m > 0
        "#{m}m #{s}s"
      else
        "#{s}s"
      end
    end
  end
end