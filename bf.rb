

edges = [
  ['e', 'a', 1],
  ['a', 'b', 2],
  ['b', 'd', 2],
  ['d', 'h', 3],
  ['l', 'm', 2],
  ['m', 'k', 2],
  ['k', 'i', 3],
  ['i', 'f', -2],
  ['f', 'c', 1],
  ['c', 'a', 1],

  ['c', 'b', 2],
  ['c', 'g', 3],

  ['g', 'i', 0],
  ['g', 'h', 3],
  ['g', 'l', 3],
  ['l', 'k', 3],
]
edges = edges + edges.map {|e| [e[1], e[0], e[2]] }
edges.map!{|e| [e[0], e[1], 1] } #if in the case where all edges are lenght 1

edge_to_w = Hash[edges.map{|e| [[e[0], e[1]], e[2]]}]

verts = edges.map {|e| e[0, 2] }.reduce(:+).uniq


paths = verts.map do |start_vert|
  prev = Hash.new { |h,k| h[k] = nil }

  dists = Hash.new { |h,k| h[k] = Float::INFINITY }
  dists[start_vert] = 0

  verts.each do |v_|
    edges.each do |e|
      u, v, w = e
      if dists[u] + w < dists[v]
        dists[v] = dists[u] + w
        prev[v] = u
      end
    end
  end

  verts.select{|v| v != start_vert }.map do |v|
    count = 0
    path = [v]
    while prev[v]
      count += edge_to_w[[prev[v], v]]
      v = prev[v]
      path << v
    end
    [count, path]
  end.max_by { |r| r[0] }
end

paths.each { |path| p path }
