require "json"
require "date"

module Dam
  class Exporter
    def initialize(since:, output_path: nil)
      @since       = since
      @output_path = output_path || File.expand_path("~/dam-report-#{Date.today}.html")
      @db          = Database.instance
    end

    def export
      summary  = @db.aggregate_by_project(since: @since)
      by_day   = @db.activity_by_day(since: @since)
      sessions = @db.sessions_detail(since: @since)
      by_proj_day = @db.aggregate_by_project_and_day(since: @since)

      html = build_html(summary, by_day, sessions, by_proj_day)
      File.write(@output_path, html)
      @output_path
    end

    private

    def build_html(summary, by_day, sessions, by_proj_day)
      total_seconds = summary.sum { |r| r["total_seconds"].to_i }
      projects      = summary.map { |r| r["project"] }.uniq

      heatmap_labels = by_day.map { |r| r["day"] }.to_json
      heatmap_data   = by_day.map { |r| (r["total_seconds"].to_i / 60.0).round(1) }.to_json

      project_labels  = projects.to_json
      project_seconds = projects.map do |p|
        summary.select { |r| r["project"] == p }.sum { |r| r["total_seconds"].to_i }
      end.to_json

      all_days = by_day.map { |r| r["day"] }
      proj_day_index = by_proj_day.each_with_object({}) do |r, h|
        h[r["project"]] ||= {}
        h[r["project"]][r["day"]] = (r["total_seconds"].to_i / 60.0).round(1)
      end

      line_datasets = projects.map.with_index do |proj, i|
        color = chart_color(i)
        data  = all_days.map { |d| proj_day_index.dig(proj, d) || 0 }
        { label: proj, data: data, borderColor: color, backgroundColor: color + "33",
          tension: 0.3, fill: false }.to_json
      end.join(",\n")

      sessions_rows = sessions.first(50).map do |s|
        "<tr>
          <td>#{s["day"]}</td>
          <td>#{s["start_time"]} → #{s["end_time"]}</td>
          <td>#{s["project"]}</td>
          <td>#{s["branch"]}</td>
          <td>#{format_duration(s["duration_s"].to_i)}</td>
        </tr>"
      end.join("\n")

      <<~HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title> Report — #{Date.today}</title>
          <script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.umd.min.js"></script>
          <style>
            *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

            body {
              font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
              background: #0f1117;
              color: #e2e8f0;
              min-height: 100vh;
              padding: 2rem;
            }

            h1 {
              font-size: 1.8rem;
              font-weight: 700;
              color: #fff;
              margin-bottom: 0.25rem;
            }

            .subtitle {
              color: #64748b;
              font-size: 0.95rem;
              margin-bottom: 2.5rem;
            }

            .stats-grid {
              display: grid;
              grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
              gap: 1rem;
              margin-bottom: 2.5rem;
            }

            .stat-card {
              background: #1e2330;
              border: 1px solid #2d3348;
              border-radius: 12px;
              padding: 1.25rem 1.5rem;
            }

            .stat-card .label {
              font-size: 0.8rem;
              color: #64748b;
              text-transform: uppercase;
              letter-spacing: 0.05em;
              margin-bottom: 0.5rem;
            }

            .stat-card .value {
              font-size: 1.8rem;
              font-weight: 700;
              color: #34d399;
            }

            .stat-card .value.blue { color: #60a5fa; }
            .stat-card .value.purple { color: #a78bfa; }

            .charts-grid {
              display: grid;
              grid-template-columns: 1fr 1fr;
              gap: 1.5rem;
              margin-bottom: 2.5rem;
            }

            @media (max-width: 768px) {
              .charts-grid { grid-template-columns: 1fr; }
            }

            .chart-card {
              background: #1e2330;
              border: 1px solid #2d3348;
              border-radius: 12px;
              padding: 1.5rem;
            }

            .chart-card.wide {
              grid-column: 1 / -1;
            }

            .chart-card h2 {
              font-size: 0.95rem;
              color: #94a3b8;
              margin-bottom: 1.25rem;
              text-transform: uppercase;
              letter-spacing: 0.05em;
            }

            .chart-wrapper {
              position: relative;
              height: 240px;
            }

            .chart-wrapper.tall {
              height: 300px;
            }

            table {
              width: 100%;
              border-collapse: collapse;
              font-size: 0.875rem;
            }

            thead th {
              text-align: left;
              padding: 0.6rem 1rem;
              color: #64748b;
              font-weight: 600;
              text-transform: uppercase;
              font-size: 0.75rem;
              letter-spacing: 0.05em;
              border-bottom: 1px solid #2d3348;
            }

            tbody tr {
              border-bottom: 1px solid #1a1f2e;
            }

            tbody tr:hover {
              background: #252b3b;
            }

            tbody td {
              padding: 0.65rem 1rem;
              color: #cbd5e1;
            }

            tbody td:first-child { color: #64748b; }
            tbody td:nth-child(3) { color: #60a5fa; font-weight: 500; }
            tbody td:nth-child(4) { color: #94a3b8; font-size: 0.8rem; }
            tbody td:last-child { color: #34d399; font-weight: 500; }

            .footer {
              margin-top: 3rem;
              text-align: center;
              color: #334155;
              font-size: 0.8rem;
            }
          </style>
        </head>
        <body>
          <h1>DAM Report</h1>
          <p class="subtitle">Generated on #{Date.today} · #{format_duration(total_seconds)} tracked</p>

          <div class="stats-grid">
            <div class="stat-card">
              <div class="label">Total time</div>
              <div class="value">#{format_duration(total_seconds)}</div>
            </div>
            <div class="stat-card">
              <div class="label">Projects</div>
              <div class="value blue">#{projects.size}</div>
            </div>
            <div class="stat-card">
              <div class="label">Sessions</div>
              <div class="value purple">#{sessions.size}</div>
            </div>
            <div class="stat-card">
              <div class="label">Active days</div>
              <div class="value">#{by_day.size}</div>
            </div>
          </div>

          <div class="charts-grid">
            <div class="chart-card">
              <h2>Time by project</h2>
              <div class="chart-wrapper">
                <canvas id="projectChart"></canvas>
              </div>
            </div>

            <div class="chart-card">
              <h2>Daily activity (minutes)</h2>
              <div class="chart-wrapper">
                <canvas id="heatChart"></canvas>
              </div>
            </div>

            <div class="chart-card wide">
              <h2>Projects over time</h2>
              <div class="chart-wrapper tall">
                <canvas id="lineChart"></canvas>
              </div>
            </div>
          </div>

          <div class="chart-card">
            <h2>Recent sessions</h2>
            <table>
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Time</th>
                  <th>Project</th>
                  <th>Branch</th>
                  <th>Duration</th>
                </tr>
              </thead>
              <tbody>
                #{sessions_rows}
              </tbody>
            </table>
          </div>

          <p class="footer">Generated by DAM · Dev Activity Monitor</p>

          <script>
            const chartDefaults = {
              color: '#94a3b8',
              borderColor: '#2d3348',
              font: { family: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif' }
            };
            Chart.defaults.color = chartDefaults.color;
            Chart.defaults.borderColor = chartDefaults.borderColor;
            Chart.defaults.font.family = chartDefaults.font.family;

            new Chart(document.getElementById('projectChart'), {
              type: 'doughnut',
              data: {
                labels: #{project_labels},
                datasets: [{
                  data: #{project_seconds},
                  backgroundColor: #{chart_colors(projects.size).to_json},
                  borderWidth: 0,
                  hoverOffset: 6
                }]
              },
              options: {
                plugins: { legend: { position: 'right' } },
                cutout: '65%',
                maintainAspectRatio: false
              }
            });

            new Chart(document.getElementById('heatChart'), {
              type: 'bar',
              data: {
                labels: #{heatmap_labels},
                datasets: [{
                  label: 'Minutes',
                  data: #{heatmap_data},
                  backgroundColor: '#34d39966',
                  borderColor: '#34d399',
                  borderWidth: 1,
                  borderRadius: 4
                }]
              },
              options: {
                plugins: { legend: { display: false } },
                scales: {
                  x: { ticks: { maxRotation: 45 } },
                  y: { beginAtZero: true }
                },
                maintainAspectRatio: false
              }
            });

            new Chart(document.getElementById('lineChart'), {
              type: 'line',
              data: {
                labels: #{all_days.to_json},
                datasets: [#{line_datasets}]
              },
              options: {
                plugins: { legend: { position: 'top' } },
                scales: {
                  x: { ticks: { maxRotation: 45 } },
                  y: { beginAtZero: true, title: { display: true, text: 'Minutes' } }
                },
                maintainAspectRatio: false
              }
            });
          </script>
        </body>
        </html>
      HTML
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

    def chart_color(index)
      colors = %w[#34d399 #60a5fa #a78bfa #f472b6 #fb923c #facc15 #22d3ee #4ade80]
      colors[index % colors.size]
    end

    def chart_colors(n)
      n.times.map { |i| chart_color(i) }
    end
  end
end