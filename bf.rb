def get_shortest_path(start_vertex, verts, edges, prev)
    edge_to_w = Hash[edges.map{|u, v, w| [[u, v], w]}]
    verts.select{|v| v != start_vertex }.map do |v|
      cost = 0
      path = [v]
      while prev[v]
        cost += edge_to_w[[prev[v], v]]
        v = prev[v]
        path << v
      end
      [cost, path]
    end.max_by { |r| r[0] }
end

def bf(verts, edges)

  verts.map do |start_vert|
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

    get_shortest_path(start_vert, verts, edges, prev)

  end
end

def d(verts, edges)
  verts.map do |start_vert|
    prev = Hash.new { |h,k| h[k] = nil }
    dists = Hash.new { |h,k| h[k] = Float::INFINITY }
    dists[start_vert] = 0

    q = verts.dup
    while !q.empty?
      u, dist = q.map{|u| [u, dists[u]]}.min_by { |u,d| d }
      q.delete(u)
      if dist == Float::INFINITY
        break
      end

      neighbors = edges.select { |u_prime,v| u == u_prime }
                       .map { |u_prime,v,w| [v,w] }
                       .select { |v,w| q.include? v }
      neighbors.each do |v,w|
        if dists[u] + w < dists[v]
          dists[v] = dists[u] + w
          prev[v] = u
        end
      end
    end

    get_shortest_path(start_vert, verts, edges, prev)
  end
end

edges = [
  ['e', 'a', 1],
  ['a', 'b', 2],
  ['b', 'd', 2],
  ['d', 'h', 3],
  ['h', 'l', 3],
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
edges = edges + edges.map {|u, v, w| [v, u, w] }
edges.map!{|e| [e[0], e[1], 1] } #if in the case where all edges are lenght 1


verts = edges.map {|u, v| [u,v] }.reduce(:+).uniq


#e2 = edges.map{|u, v, w| [u, v, w+2] } #otherwise, becasuse negative weights
#bf(verts, e2).sort_by { |r| r[0] }.each{|x| p x}
d(verts, edges).sort_by { |r| r[0] }.each{|x| p x}

