#!/usr/bin/env python
# coding: utf-8

import pandas as pd
import numpy as np
from ete3 import ClusterTree, TreeStyle, Tree
import scipy.cluster.hierarchy as sch
import scipy.spatial.distance
from itertools import combinations
import xml.etree.ElementTree as ET

#Read xml
tree = ET.parse('total_fs_linked.tree.xml') 
root = tree.getroot() 
for child in root:
    print(child.tag, child.attrib)

for i in root.iter('Tree'):
    poptree = i.text
    
dendtree = Tree(poptree) #from ete3

leaves = dendtree.get_leaf_names()
n = len(leaves)
dmat = np.zeros((n,n))

for l1,l2 in combinations(leaves,2):
    d = dendtree.get_distance(l1,l2)
    dmat[leaves.index(l1),leaves.index(l2)] = dmat[leaves.index(l2),leaves.index(l1)] = d
    
schlink = sch.linkage(scipy.spatial.distance.squareform(dmat),method='average',metric='euclidean')
np.savetxt('DistMat_fromFS.txt', schlink, fmt='%f')

#To load
#b = np.loadtxt('DistMat_fromFS.txt', dtype=float)

