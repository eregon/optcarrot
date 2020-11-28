require "csv"
require "pycall/import"
include PyCall::Import

pyimport "numpy", as: "np"
pyimport "pandas", as: "pd"
pyimport "matplotlib.pyplot", as: "plt"

fps_df = pd.read_csv(ARGV[0], index_col: "frame")

[fps_df[1..180], fps_df[1..1000], fps_df[1..-1]].each do |df|
  baselines = df.columns.tolist.to_a.grep(/mri-2\.0/)
  baseline_means = baselines.map { |col| df[col][25..-1].mean.to_f }

  ax = df.plot(title: "fps history (up to #{ PyCall.len(df) } frames)", figsize: [12, 8])
  ax.set_xlabel("frames")
  ax.set_ylabel("frames per second")
  unless baseline_means.empty?
    ax.axhspan(ymin: baseline_means.min, ymax: baseline_means.max, facecolor: '0.5')
    ax.axhspan(ymin: baseline_means.min*3, ymax: baseline_means.max*3)
  end
  ax.axvline(x: 180)
  plt.savefig("doc/fps-history-#{ PyCall.len(df) }.png", dpi: 80, bbox_inches: "tight")
  plt.close
end
