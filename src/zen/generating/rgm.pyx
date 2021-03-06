"""
This module implements standard random graph models.
"""
from zen.graph cimport Graph
from zen.digraph cimport DiGraph
from zen.exceptions import ZenException
from libc.stdlib cimport RAND_MAX, rand, srand
from cpython cimport bool

__all__ = ['erdos_renyi','barabasi_albert']

def barabasi_albert(n, m, **kwargs):
	"""
	Generate a random graph using the Barabasi-Albert preferential attachment model.
	
	**Args**:
	
		* ``n`` (int): the number of nodes to add to the graph
		* ``m`` (int): the number of edges a new node will add to the graph
	
	**KwArgs**:
		* ``directed [=False]`` (boolean): whether to build the graph directed.  If ``True``, then the ``m`` edges created
		  by a node upon its creation are instantiated as out-edges.  All others are in-edges to that node.
		* ``seed [=-1]`` (int): a seed for the random number generator
	
	**Returns**:
		:py:class:`zen.Graph` or :py:class:`zen.DiGraph`. The graph generated.  If ``directed = True``, then a :py:class:`DiGraph` will be returned.
	
	.. note::
		Source: A. L. Barabási and R. Albert "Emergence of scaling in random networks", Science 286, pp 509-512, 1999.
	"""
	seed = kwargs.pop('seed',None)
	directed = kwargs.pop('directed',False)
	
	if len(kwargs) > 0:
		raise ZenException, 'Unknown arguments: %s' % ', '.join(kwargs.keys())
		
	if seed is None:
		seed = -1
	
	if not directed:
		return __inner_barabasi_albert_udir(n, m, seed)
	else:
		return __inner_barabasi_albert_dir(n, m, seed)
	
def identity_fxn(i):
	return i	
	
cdef __inner_barabasi_albert_udir(int n, int m, int seed):
	
	cdef Graph G = Graph()
	cdef int new_node_idx, i, e
	cdef int rnd
	cdef int num_endpoints
	cdef int running_sum
	cdef bool edge_made
	
	# add nodes
	G.add_nodes(n, identity_fxn)
	
	#####
	# add edges
	if seed >= 0:
		srand(seed)
	
	# add the first (m+1)th node
	for i in range(m):
		G.add_edge_(m,i)
	
	# add the remaining nodes
	num_endpoints = 2 * m
	for new_node_idx in range(m+1,n):
		
		# this node drops m edges
		delta_endpoints = 0
		for e in range(m):
			rnd = rand() % (num_endpoints-delta_endpoints)
			
			# now loop through nodes and find the one whose endpoint has the running sum
			# note that we ignore nodes that we already have a connection to
			running_sum = 0
			for i in range(new_node_idx):
				if G.has_edge_(new_node_idx,i):
					continue
					
				running_sum += G.node_info[i].degree
				if running_sum > rnd:
					G.add_edge_(new_node_idx,i)
					
					# this node can no longer be selected.  So we remove this node's degree
					# from the total degree of the network - making sure that a node will get
					# selected next time.  We decrease by 1 because the node's degree has just
					# been updated by 1 because it gained an endpoint from the node being
					# added.  This edge isn't included in the number of endpoints until the 
					# node has finished being added (since the node can't connect to itself).
					# As a result the delta endpoints must not include this edge either.
					delta_endpoints += G.node_info[i].degree - 1
					break
					
		num_endpoints += m * 2
		
	return G

cdef __inner_barabasi_albert_dir(int n, int m, int seed):

	cdef DiGraph G = DiGraph()
	cdef int new_node_idx, i, e
	cdef int rnd
	cdef int num_endpoints
	cdef int running_sum
	cdef bool edge_made
	cdef int node_degree
	
	# add nodes
	G.add_nodes(n, identity_fxn)

	#####
	# add edges
	if seed >= 0:
		srand(seed)

	# add the first (m+1)th node
	for i in range(m):
		G.add_edge_(m,i)

	# add the remaining nodes
	num_endpoints = 2 * m
	for new_node_idx in range(m+1,n):

		# this node drops m edges
		delta_endpoints = 0
		for e in range(m):
			rnd = rand() % (num_endpoints-delta_endpoints)

			# now loop through nodes and find the one whose endpoint has the running sum
			# note that we ignore nodes that we already have a connection to
			running_sum = 0
			for i in range(new_node_idx):
				if G.has_edge_(new_node_idx,i):
					continue

				node_degree = G.node_info[i].indegree + G.node_info[i].outdegree
				running_sum += node_degree
				if running_sum > rnd:
					G.add_edge_(new_node_idx,i)
					
					# this node can no longer be selected.  So we remove this node's degree
					# from the total degree of the network - making sure that a node will get
					# selected next time.
					delta_endpoints += node_degree
					break

		num_endpoints += m * 2
		
	return G

def erdos_renyi(int n,float p,**kwargs):
	"""
	Generate an Erdos-Renyi graph.
	
	**Args**:
	 	* ``num_nodes`` (int): the number of nodes to populate the graph with.
	 	* ``p`` (0 <= float <= 1): the probability p given to each edge's existence.
	
	**KwArgs**:
		* ``directed [=False]`` (boolean): indicates whether the network generated is directed.
		* ``self_loops [=False]`` (boolean): indicates whether self-loops are permitted in the generated graph.
		* ``seed [=-1]`` (int): the seed provided to the random generator used to drive the graph construction.
	"""
	directed = kwargs.pop('directed',False)
	self_loops = kwargs.pop('self_loops',False)
	seed = kwargs.pop('seed',None)
	
	if len(kwargs) > 0:
		raise ZenException, 'Unknown arguments: %s' % ', '.join(kwargs.keys())
		
	if seed is None:
		seed = -1
	
	if directed:
		return __erdos_renyi_directed(n,p,self_loops,seed)
	else:
		return __erdos_renyi_undirected(n,p,self_loops,seed)

cpdef __erdos_renyi_undirected(int num_nodes,float p,bint self_loops,int seed):
	cdef Graph G = Graph()
	cdef int i, j, first_j
	cdef float rnd
	
	if seed >= 0:
		srand(seed)
	
	# add nodes
	for i in range(num_nodes):
		G.add_node(i)
		
	# add edges
	for i in range(num_nodes):
		if self_loops:
			first_j = i
		else:
			first_j = i+1
			
		for j in range(first_j,num_nodes):
			rnd = rand()
			rnd = rnd / (<float> RAND_MAX)
			if rnd < p:
				G.add_edge_(i,j)
	
	return G
	
cpdef __erdos_renyi_directed(int num_nodes,float p,bint self_loops,int seed):
	cdef DiGraph G = DiGraph()
	cdef int i, j
	cdef float rnd

	if seed >= 0:
		srand(seed)
	
	# add nodes
	for i in range(num_nodes):
		G.add_node(i)
	
	# add edges
	for i in range(num_nodes):
		for j in range(num_nodes):
			if i == j and not self_loops:
				continue
				
			rnd = rand()
			rnd = rnd / (<float> RAND_MAX)
			if rnd < p:
				G.add_edge_(i,j)

	return G