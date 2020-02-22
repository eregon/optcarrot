require "csv"
require "pycall/import"
include PyCall::Import

pyimport "numpy", as: "np"
pyimport "pandas", as: "pd"
pyimport "matplotlib.pyplot", as: "plt"

fps_df = pd.read_csv(ARGV[0], index_col: "frame")
[fps_df[1..180], fps_df].each do |df_|
  ax = df_.plot(title: "fps history (up to #{ PyCall.len(df_) } frames)", figsize: [12, 8])
  ax.set_xlabel("frames")
  ax.set_ylabel("frames per second")
  plt.savefig("doc/fps-history-#{ PyCall.len(df_) }.png", dpi: 80, bbox_inches: "tight")
  plt.close
end
