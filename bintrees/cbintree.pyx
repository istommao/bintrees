#!/usr/bin/env python
#coding:utf-8
# Author:  mozman
# Purpose: cython abstract tree module
# Created: 28.04.2010

from itertools import izip
from random import shuffle

__all__ = ['cBinaryTree']

cdef class Node:
    cdef Node left
    cdef Node right
    cdef object key
    cdef object value

    def __init__(self, object key, object value):
        self.left = None
        self.right = None
        self.key = key
        self.value = value

    cdef Node link(self, int key):
        """Get left (key==0) or right (key==1) node by index"""
        # this is a little bit faster as __getitem__
        return self.left if key == 0 else self.right

    def __getitem__(self, int key):
        """Get left (key==0) or right (key==1) node by index"""
        return self.left if key == 0 else self.right

    def __setitem__(self, int key, value):
        """Set left (key==0) or right (key==1) node by index"""
        if key == 0:
            self.left = value
        else:
            self.right = value

    cdef void free(self):
        self.left = None
        self.right = None
        self.key = None
        self.value = None

cdef void tree_to_str(Node node, result):
    if node is not None:
        tree_to_str(node.left, result)
        tree_to_str(node.right, result)
        result.append(repr(node.key)+': '+repr(node.value))

cdef void clear_tree(Node node):
    if node is not None:
        clear_tree(node.left)
        clear_tree(node.right)
        node.free()

cdef void traverse_inorder(Node node, object func):
    if node is not None:
        traverse_inorder(node.left, func)
        func(node.value)
        traverse_inorder(node.right, func)

cdef void traverse_preorder(Node node, object func):
    if node is not None:
        func(node.value)
        traverse_preorder(node.left, func)
        traverse_preorder(node.right, func)

cdef void traverse_postorder(Node node, object func):
    if node is not None:
        traverse_postorder(node.left, func)
        traverse_postorder(node.right, func)
        func(node.value)

cdef void add_values(Node node, result):
    if node is not None:
        add_values(node.left, result)
        result.append(node.value)
        add_values(node.right, result)

cdef void add_keys(Node node, result):
    if node is not None:
        add_keys(node.left, result)
        result.append(node.key)
        add_keys(node.right, result)

cdef Node get_leaf(Node node):
    while True:
        if node.left is not None:
            node = node.left
        elif node.right is not None:
            node = node.right
        else:
            return node

cdef class cBinaryTree:
    cdef object root
    cdef object compare
    cdef int _count

    def __init__(self, items=[], compare=None):
        self.root = None
        self.compare = compare if compare is not None else cmp
        self._count = 0
        self.update(items)

    def __copy__(self):
        return self.copy()

    def __repr__(self):
        result = []
        tree_to_str(self.root, result)
        return "{{{0}}}".format(", ".join(result))

    def has_key(self, key):
        cdef Node node
        node = self.find_node(key)
        return node is not None

    def __contains__(self, key):
        return self.has_key(key)

    def clear(self):
        clear_tree(self.root)
        self._count = 0
        self.root = None

    def __len__(self):
        return self._count

    def is_empty(self):
        return (self.root is None)

    def keys(self):
        result = []
        add_keys(self.root, result)
        return result

    def iterkeys(self):
        return iter(self.keys())

    def __iter__(self):
        return iter(self.keys())

    def values(self):
        result = list()
        add_values(self.root, result)
        return result

    def itervalues(self):
        return iter(self.values())

    def iteritems(self):
        return izip(self.keys(), self.values())

    def items(self):
        return zip(self.keys(), self.values())

    def __getitem__(self, key):
        cdef Node node
        node = self.find_node(key)
        if node is None:
            raise KeyError(unicode(key))
        return node.value

    def __setitem__(self, key, value):
        self.insert(key, value)

    def __delitem__(self, key):
        self.remove(key)

    def __cmp__(self, other):
        if other is None:
            return 1
        if isinstance(other, cBaseTree):
            for key in self.iterkeys():
                value1 = self.__getitem__(key)
                try:
                    value2 = other.__getitem__(key)
                except KeyError:
                    # if <key> does not exists in <other>, <self> is greater
                    # than <other>
                    return 1
                cmp_res = cmp(value1, value2)
                if cmp_res != 0:
                    return cmp_res
            return 0
        else:
            raise ValueError('<self> is not comparable with <other>')

    def setdefault(self, key, default=None):
        cdef Node node
        node = self.find_node(key)
        if node is None:
            self.insert(key, default)
            return default
        return node.value

    def foreach(self, func, order='inorder'):
        """Visit all tree nodes and process node-value.

        func -- function(node.value)

        order -- 'inorder', 'preorder', 'postorder'
        """
        if order=='inorder':
            traverse_inorder(self.root, func)
        elif order=='postorder':
            traverse_postorder(self.root, func)
        elif order=='preorder':
            traverse_preorder(self.root, func)
        else:
            raise ValueError("foreach(): unknown order '{0}'.".format(order))

    def update(self, items):
        try:
            generator = items.iteritems()
        except AttributeError:
            generator = iter(items)

        for key, value in generator:
            self.insert(key, value)

    @classmethod
    def fromkeys(cls, iterable, value=None):
        tree = cls()
        for key in iterable:
            tree.insert(key, value)
        return tree

    def get(self, key, default=None):
        cdef Node node
        node = self.find_node(key)
        if node is None:
            return default
        else:
            return node.value

    def pop(self, key, *args):
        cdef Node node
        if len(args) > 1:
            raise TypeError("pop expected at most 2 arguments, got {0}".format(
                              1+len(args)))

        node = self.find_node(key)
        if node is None:
            if len(args) == 0:
                raise KeyError(unicode(key))
            else:
                return args[0]
        value = node.value
        self.remove(key)
        return value

    def popitem(self):
        cdef Node node
        if self.is_empty():
            raise KeyError("popitem(): tree is empty")
        node = get_leaf(self.root)
        result = (node.key, node.value)
        self.remove(node.key)
        return result

    cdef Node find_node(self, object key):
        cdef int cval
        cdef Node node
        compare = self.compare
        node = self.root
        while True:
            if node is None:
                return None
            cval = <int>compare(key, node.key)
            if cval == 0:
                return node
            elif cval < 0:
                node = node.left
            else:
                node = node.right

    def copy(self):
        treekeys = self.keys()
        shuffle(treekeys)  # sorted keys generates a linked list!
        newtree = cBinaryTree()
        for key in treekeys:
            newtree[key] = self[key]
        return newtree

    def __len__(self):
        return self._count

    cdef Node new_node(self, key, value):
        """Create a new tree node."""
        self._count += 1
        return Node(key, value)

    def insert(self, key, value):
        cdef Node parent, node
        cdef int direction, cval

        if self.root is None:
            self.root = self.new_node(key, value)
        else:
            compare = self.compare
            direction = 0
            parent = None
            node = self.root
            while True:
                if node is None:
                    parent[direction] = self.new_node(key, value)
                    break
                cval = <int> compare(key, node.key)
                if cval == 0: # key exists
                    node.value = value # replace value
                    break
                else:
                    parent = node
                    direction = 0 if cval < 0 else 1
                    node = node.link(direction)

    def remove(self, key):
        cdef Node node, parent, child
        cdef int direction, cmp_res, down_dir
        cdef object tmp

        node = self.root
        if node is None:
            raise KeyError(str(key))
        else:
            compare = self.compare
            parent = None
            direction = 0
            while True:
                cmp_res = <int> compare(key, node.key)
                if cmp_res == 0:
                    # remove node
                    if (node.left is not None) and (node.right is not None):
                        # find replacment node: smallest key in right-subtree
                        child = node.right
                        while child.left is not None:
                            child = child.left

                        #swap places
                        tmp = child.key
                        child.key = node.key
                        node.key = tmp

                        tmp = child.value
                        child.value = node.value
                        node.value = tmp

                        parent = node
                        direction = 1
                        node = node.right
                        continue
                    else:
                        down_dir = 1 if node.left is None else 0
                        if parent is None: # root
                            self.root = node.link(down_dir)
                        else:
                            parent[direction] = node.link(down_dir)
                    node.free()
                    self._count -= 1
                    break
                else:
                    direction = 0 if cmp_res < 0 else 1
                    parent = node
                    node = node.link(direction)
                    if node is None:
                        raise KeyError(str(key))
