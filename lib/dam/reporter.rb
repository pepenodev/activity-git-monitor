require "tty-table"

module Dam
  class Reporter
    def initialize(since:)
      @since = since
      @db    = Database.instance
    end

    def print_summary(title:)
      rows = @db.aggregate_by_project(since: @since)

      if rows.empty?
        puts "\nNo activity for this period.\n"
        return
      end

      table = TTY::Table.new(
        header: ["Project", "Branch", "Sessions", "Time"],
        rows: rows.map do |r|
          [
            r["project"],
            r["branch"],
            r["session_count"].to_s,
            format_duration(r["total_seconds"].to_i)
          ]
        end
      )

      total = rows.sum { |r| r["total_seconds"].to_i }

      puts "\n#{title}"
      puts table.render(:unicode, padding: [0, 1])
      puts "\nTotal: #{format_duration(total)}\n"
    end

    private

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