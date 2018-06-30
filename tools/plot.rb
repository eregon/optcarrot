require "csv"
require "pycall/import"
include PyCall::Import

pyimport "numpy", as: "np"
pyimport "pandas", as: "pd"
pyimport "matplotlib.pyplot", as: "plt"

oneshot_file = ARGV.grep(/oneshot/).first
elapsed_time = ARGV.grep(/elapsed-time/).first
fps_history = ARGV.grep(/fps-history/).first

[true, false].each do |oneshot|
  next unless file = oneshot ? oneshot_file : elapsed_time
  df = pd.read_csv(file, index_col: ["mode", "name"])
  df = df[df.index.get_level_values(1) != "jruby9k"]
  df = df[df.index.get_level_values(1) != "jruby17"]
  df = df.filter(regex: "run \\d+").stack().to_frame("fps")
  idx = df.index.drop_duplicates
  gp = df["fps"].groupby(level: ["mode", "name"])
  (oneshot ? [true, false] : [true]).each do |summary|
    mean, std = [gp.mean(), gp.std()].map do |df_|
      df_ = df_.unstack("mode")
      df_ = df_.reindex(index: idx.get_level_values("name").unique)
      df_ = df_.reindex(columns: idx.get_level_values("mode").unique)
      if oneshot && summary
        if PyCall::List.new(df_.columns).include? 'opt-none'
          df_ = df_["default"].fillna(df_["opt-none"]).to_frame
        else
          df_ = df_["default"].to_frame
        end
      end
      df_
    end
    ax = mean.plot(
      kind: :barh, figsize: [8, oneshot ? summary ? 7 : 13 : 2], width: 0.8,
      xerr: std, ecolor: "lightgray", legend: !summary)
    ax.set_title(
      oneshot ?
        "Ruby implementation benchmark with Optcarrot (180 frames)"
      :
        "Start-up time (the time to show the first frame)"
    )
    ax.set_xlabel(oneshot ? "frames per second" : "seconds")
    ax.set_ylabel("")
    ax.invert_yaxis()
    texts = mean.applymap(->(v) do
      v.nan? ? "failure" : "%.#{ (2 - Math.log(v.to_f, 10)).ceil }f" % v
    end)
    ax.patches.each_with_index do |rect, i|
      x = rect.get_width() + 0.1
      y = rect.get_y() + rect.get_height() / 2
      n = PyCall.len(mean)
      text = texts.iloc[i % n, i / n]
      ax.text(x, y, text, ha: "left", va: "center")
    end
    f = oneshot ?
      summary ? "doc/benchmark-summary.png" : "doc/benchmark-full.png"
    :
      "doc/startup-time.png"
    plt.savefig(f, dpi: 80, bbox_inches: "tight")
    plt.close()
  end
end

if fps_history
  fps_df = pd.read_csv(fps_history, index_col: "frame")
  selected = PyCall::List.new(fps_df.columns)
  # selected = PyCall::List.new(["ruby25", "ruby20", "truffleruby", "jruby9koracle", "topaz"])
  fps_df = fps_df[selected]
  [fps_df[1..180], fps_df].each do |df_|
    ax = df_.plot(title: "fps history (up to #{ PyCall.len(df_) } frames)", figsize: [8, 6])
    ax.set_xlabel("frames")
    ax.set_ylabel("frames per second")
    file = "doc/fps-history-#{ PyCall.len(df_) }.png"
    plt.savefig(file, dpi: 80, bbox_inches: "tight")
    plt.close
    puts file
  end
end
