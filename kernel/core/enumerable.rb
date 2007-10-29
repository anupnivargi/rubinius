#  The <code>Enumerable</code> mixin provides collection classes with
#  several traversal and searching methods, and with the ability to
#  sort. The class must provide a method <code>each</code>, which
#  yields successive members of the collection. If
#  <code>Enumerable#max</code>, <code>#min</code>, or
#  <code>#sort</code> is used, the objects in the collection must also
#  implement a meaningful <code><=></code> operator, as these methods
#  rely on an ordering between members of the collection.
module Enumerable

  class Sort

    def initialize(sorter = :quicksort)
      @sorter = sorter
    end

    def sort(xs, &prc)
      # The ary should be inmutable while sorting
      prc = lambda { |a,b| a <=> b } unless block_given?
      @sorter = method(@sorter) unless @sorter.respond_to?(:call)
      @sorter.call(xs, &prc)
    end

    alias_method :call, :sort

    def sort_by(xs, &prc)
      # The ary and its elements sould be inmutable while sorting
      sort(xs.collect { |x| 
             [yield(x), x] 
           }).collect { |a| a[1] }
    end
    
    # Sort an Enumerable using simple quicksort (not optimized)
    def quicksort(xs, &prc)
      return [] unless xs
      pivot = nil
      xs.each { |o| pivot = o; break }
      return xs if pivot.nil?

      lmr = xs.group_by do |o|
        if o.equal?(pivot)
          0
        else
          yield(o, pivot)
        end
      end

      quicksort(lmr[-1], &prc) + lmr[0] + quicksort(lmr[1], &prc)
    end

  end

  # :call-seq:
  #     enum.to_a      =>    array
  #     enum.entries   =>    array
  #  
  #  Returns an array containing the items in <i>enum</i>.
  #     
  #     (1..7).to_a                       #=> [1, 2, 3, 4, 5, 6, 7]
  #     { 'a'=>1, 'b'=>2, 'c'=>3 }.to_a   #=> [["a", 1], ["b", 2], ["c", 3]]
  def to_a
    ary = []
    each { |o| ary << o }
    ary
  end

  alias_method :entries, :to_a

  #  :call-seq:
  #     enum.grep(pattern)                   => array
  #     enum.grep(pattern) {| obj | block }  => array
  #  
  #  Returns an array of every element in <i>enum</i> for which
  #  <code>Pattern === element</code>. If the optional <em>block</em> is
  #  supplied, each matching element is passed to it, and the block's
  #  result is stored in the output array.
  #     
  #     (1..100).grep 38..44   #=> [38, 39, 40, 41, 42, 43, 44]
  #     c = IO.constants
  #     c.grep(/SEEK/)         #=> ["SEEK_END", "SEEK_SET", "SEEK_CUR"]
  #     res = c.grep(/SEEK/) {|v| IO.const_get(v) }
  #     res                    #=> [2, 0, 1]
  def grep(pattern)
    ary = []
    each do |o|
      if pattern === o
        ary << (block_given? ? yield(o) : o)
      end
    end
    ary
  end

  def sorter
    Enumerable::Sort.new
  end

  #  :call-seq:
  #     enum.sort                     => array
  #     enum.sort {| a, b | block }   => array
  #  
  #  Returns an array containing the items in <i>enum</i> sorted,
  #  either according to their own <code><=></code> method, or by using
  #  the results of the supplied block. The block should return -1, 0, or
  #  +1 depending on the comparison between <i>a</i> and <i>b</i>. As of
  #  Ruby 1.8, the method <code>Enumerable#sort_by</code> implements a
  #  built-in Schwartzian Transform, useful when key computation or
  #  comparison is expensive..
  #     
  #     %w(rhea kea flea).sort         #=> ["flea", "kea", "rhea"]
  #     (1..10).sort {|a,b| b <=> a}   #=> [10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
  def sort(&prc)
    sorter.sort(self, &prc)
  end

 #  :call-seq:
 #     enum.sort_by {| obj | block }    => array
 #  
 #  Sorts <i>enum</i> using a set of keys generated by mapping the
 #  values in <i>enum</i> through the given block.
 #     
 #     %w{ apple pear fig }.sort_by {|word| word.length}
 #                   #=> ["fig", "pear", "apple"]
 #     
 #  The current implementation of <code>sort_by</code> generates an
 #  array of tuples containing the original collection element and the
 #  mapped value. This makes <code>sort_by</code> fairly expensive when
 #  the keysets are simple
 #     
 #     require 'benchmark'
 #     include Benchmark
 #     
 #     a = (1..100000).map {rand(100000)}
 #     
 #     bm(10) do |b|
 #       b.report("Sort")    { a.sort }
 #       b.report("Sort by") { a.sort_by {|a| a} }
 #     end
 #     
 #  <em>produces:</em>
 #     
 #     user     system      total        real
 #     Sort        0.180000   0.000000   0.180000 (  0.175469)
 #     Sort by     1.980000   0.040000   2.020000 (  2.013586)
 #     
 #  However, consider the case where comparing the keys is a non-trivial
 #  operation. The following code sorts some files on modification time
 #  using the basic <code>sort</code> method.
 #     
 #     files = Dir["#"]
 #     sorted = files.sort {|a,b| File.new(a).mtime <=> File.new(b).mtime}
 #     sorted   #=> ["mon", "tues", "wed", "thurs"]
 #     
 #  This sort is inefficient: it generates two new <code>File</code>
 #  objects during every comparison. A slightly better technique is to
 #  use the <code>Kernel#test</code> method to generate the modification
 #  times directly.
 #     
 #     files = Dir["#"]
 #     sorted = files.sort { |a,b|
 #       test(?M, a) <=> test(?M, b)
 #     }
 #     sorted   #=> ["mon", "tues", "wed", "thurs"]
 #     
 #  This still generates many unnecessary <code>Time</code> objects. A
 #  more efficient technique is to cache the sort keys (modification
 #  times in this case) before the sort. Perl users often call this
 #  approach a Schwartzian Transform, after Randal Schwartz. We
 #  construct a temporary array, where each element is an array
 #  containing our sort key along with the filename. We sort this array,
 #  and then extract the filename from the result.
 #     
 #     sorted = Dir["#"].collect { |f|
 #        [test(?M, f), f]
 #     }.sort.collect { |f| f[1] }
 #     sorted   #=> ["mon", "tues", "wed", "thurs"]
 #     
 #  This is exactly what <code>sort_by</code> does internally.
 #     
 #     sorted = Dir["#"].sort_by {|f| test(?M, f)}
 #     sorted   #=> ["mon", "tues", "wed", "thurs"]
  def sort_by(&prc)
    sorter.sort_by(self, &prc)
  end

  #  :call-seq:
  #     enum.count(item)             => int
  #     enum.count {| obj | block }  => int
  #  
  #  Returns the number of items in <i>enum</i> for which equals to <i>item</i>.
  #  If a block is given, counts the number of elements yielding a true value.
  #     
  #     ary = [1, 2, 4, 2]
  #     ary.count(2)          # => 2
  #     ary.count{|x|x%2==0}  # => 3
  def count(item=nil)
    seq = 0
    if item
      each { |o| seq += 1 if item == o }
    else 
      each { |o| seq += 1 if yield(o) }
    end
    seq
  end
  

  #  :call-seq:
  #     enum.detect(ifnone = nil) {| obj | block }  => obj or nil
  #     enum.find(ifnone = nil)   {| obj | block }  => obj or nil
  #  
  #  Passes each entry in <i>enum</i> to <em>block</em>. Returns the
  #  first for which <em>block</em> is not <code>false</code>.  If no
  #  object matches, calls <i>ifnone</i> and returns its result when it
  #  is specified, or returns <code>nil</code>
  #     
  #     (1..10).detect  {|i| i % 5 == 0 and i % 7 == 0 }   #=> nil
  #     (1..100).detect {|i| i % 5 == 0 and i % 7 == 0 }   #=> 35
  #     
  def find(ifnone = nil)
    each { |o| return o if yield(o) }
    ifnone.call if ifnone
  end

  alias_method :detect, :find
  
  #  :call-seq:
  #     enum.find_index(ifnone = nil)   {| obj | block }  => int
  #  
  #  Passes each entry in <i>enum</i> to <em>block</em>. Returns the
  #  index for the first for which <em>block</em> is not <code>false</code>.
  #  If no object matches, returns <code>nil</code>
  #     
  #     (1..10).find_index  {|i| i % 5 == 0 and i % 7 == 0 }   #=> nil
  #     (1..100).find_index {|i| i % 5 == 0 and i % 7 == 0 }   #=> 35
  #     
  def find_index(ifnone = nil)
    idx = -1
    each { |o| idx += 1; return idx if yield(o) }
    ifnone.call if ifnone
  end


  #  :call-seq:
  #     enum.find_all {| obj | block }  => array
  #     enum.select   {| obj | block }  => array
  #  
  #  Returns an array containing all elements of <i>enum</i> for which
  #  <em>block</em> is not <code>false</code> (see also
  #  <code>Enumerable#reject</code>).
  #     
  #     (1..10).find_all {|i|  i % 3 == 0 }   #=> [3, 6, 9]
  #     
  def find_all
    ary = []
    each do |o|
      if yield(o)
        ary << o
      end
    end
    ary
  end

  alias_method :select, :find_all

  #  :call-seq:
  #     enum.reject {| obj | block }  => array
  #  
  #  Returns an array for all elements of <i>enum</i> for which
  #  <em>block</em> is false (see also <code>Enumerable#find_all</code>).
  #     
  #     (1..10).reject {|i|  i % 3 == 0 }   #=> [1, 2, 4, 5, 7, 8, 10]
  def reject
    ary = []
    each do |o|
      unless yield(o)
        ary << o
      end
    end
    ary
  end
  
  
  #  :call-seq:
  #     enum.collect {| obj | block }  => array
  #     enum.map     {| obj | block }  => array
  #  
  #  Returns a new array with the results of running <em>block</em> once
  #  for every element in <i>enum</i>.
  #     
  #     (1..4).collect {|i| i*i }   #=> [1, 4, 9, 16]
  #     (1..4).collect { "cat"  }   #=> ["cat", "cat", "cat", "cat"]
  def collect
    ary = []
    each { |o| ary << yield(o) }
    ary
  end

  alias_method :map, :collect

  #  :call-seq:
  #     enum.inject(initial) {| memo, obj | block }  => obj
  #     enum.inject          {| memo, obj | block }  => obj
  #  
  #  Combines the elements of <i>enum</i> by applying the block to an
  #  accumulator value (<i>memo</i>) and each element in turn. At each
  #  step, <i>memo</i> is set to the value returned by the block. The
  #  first form lets you supply an initial value for <i>memo</i>. The
  #  second form uses the first element of the collection as a the
  #  initial value (and skips that element while iterating).
  #     
  #     # Sum some numbers
  #     (5..10).inject {|sum, n| sum + n }              #=> 45
  #     # Multiply some numbers
  #     (5..10).inject(1) {|product, n| product * n }   #=> 151200
  #     
  #     # find the longest word
  #     longest = %w{ cat sheep bear }.inject do |memo,word|
  #        memo.length > word.length ? memo : word
  #     end
  #     longest                                         #=> "sheep"
  #     
  #     # find the length of the longest word
  #     longest = %w{ cat sheep bear }.inject(0) do |memo,word|
  #        memo >= word.length ? memo : word.length
  #     end
  #     longest                                         #=> 5
  def inject(memo = nil)
    first_item = true

    each { |o|
      if first_item 
        first_item = false

        if memo.nil?
          memo = o
          next
        end
      end

      memo = yield(memo, o)
    }

    memo
  end 

  # :call-seq:
  #     enum.partition {| obj | block }  => [ true_array, false_array ]
  #  
  #  Returns two arrays, the first containing the elements of
  #  <i>enum</i> for which the block evaluates to true, the second
  #  containing the rest.
  #     
  #     (1..6).partition {|i| (i&1).zero?}   #=> [[2, 4, 6], [1, 3, 5]]
  #     
  def partition
    left = []
    right = []
    each { |o| yield(o) ? left.push(o) : right.push(o) }
    return [left, right]
  end


  #  :call-seq:
  #     enum.group_by {| obj | block }  => a_hash
  #  
  #  Returns a hash, which keys are evaluated result from the
  #  block, and values are arrays of elements in <i>enum</i>
  #  corresponding to the key.
  #     
  #     (1..6).group_by {|i| i%3}   #=> {0=>[3, 6], 1=>[1, 4], 2=>[2, 5]}
  def group_by
    h = {}
    each do |o|
      key = yield(o)
      if h.key?(key)
        h[key] << o
      else
        h[key] = [o]
      end
    end
    h
  end

  #  :call-seq:
  #     enum.first      -> obj or nil
  #     enum.first(n)   -> an_array
  #  
  #  Returns the first element, or the first +n+ elements, of the enumerable.
  #  If the enumerable is empty, the first form returns <code>nil</code>, and the
  #  second form returns an empty array.
  def first(n = nil)
    if n && n < 0 
      raise ArgumentError, "Invalid number of elements given."
    end
    ary = []
    each do |o|
      return o unless n
      return ary if ary.size == n
      ary << o
    end
    n ? ary : nil
  end

  #  :call-seq:
  #     enum.all? [{|obj| block } ]   => true or false
  #  
  #  Passes each element of the collection to the given block. The method
  #  returns <code>true</code> if the block never returns
  #  <code>false</code> or <code>nil</code>. If the block is not given,
  #  Ruby adds an implicit block of <code>{|obj| obj}</code> (that is
  #  <code>all?</code> will return <code>true</code> only if none of the
  #  collection members are <code>false</code> or <code>nil</code>.)
  #     
  #     %w{ant bear cat}.all? {|word| word.length >= 3}   #=> true
  #     %w{ant bear cat}.all? {|word| word.length >= 4}   #=> false
  #     [ nil, true, 99 ].all?                            #=> false
  def all?(*args, &prc)
    raise ArgumentError, "wrong number of arguments (#{args.size} for 0)" unless args.empty?
    
    prc = lambda { |obj| obj } unless block_given?
    each { |o| return false unless prc.call(o) }
    true
  end

  #  :call-seq:
  #     enum.any? [{|obj| block } ]   => true or false
  #  
  #  Passes each element of the collection to the given block. The method
  #  returns <code>true</code> if the block ever returns a value other
  #  than <code>false</code> or <code>nil</code>. If the block is not
  #  given, Ruby adds an implicit block of <code>{|obj| obj}</code> (that
  #  is <code>any?</code> will return <code>true</code> if at least one
  #  of the collection members is not <code>false</code> or
  #  <code>nil</code>.
  #     
  #     %w{ant bear cat}.any? {|word| word.length >= 3}   #=> true
  #     %w{ant bear cat}.any? {|word| word.length >= 4}   #=> true
  #     [ nil, true, 99 ].any?                            #=> true
  def any?(&prc)
    prc = lambda { |obj| obj } unless block_given?
    each { |o| return true if prc.call(o) }
    false
  end

  #  :call-seq:
  #     enum.one? [{|obj| block }]   => true or false
  #  
  #  Passes each element of the collection to the given block. The method
  #  returns <code>true</code> if the block returns <code>true</code>
  #  exactly once. If the block is not given, <code>one?</code> will return
  #  <code>true</code> only if exactly one of the collection members are
  #  true.
  #     
  #     %w{ant bear cat}.one? {|word| word.length == 4}   #=> true
  #     %w{ant bear cat}.one? {|word| word.length >= 4}   #=> false
  #     [ nil, true, 99 ].one?                            #=> true
  #     
  def one?(&prc)
    prc = lambda { |obj| obj } unless block_given?
    times = 0
    each { |o| times += 1 if prc.call(o) }
    times == 1
  end


  #  :call-seq:
  #     enum.none? [{|obj| block }]   => true or false
  #  
  #  Passes each element of the collection to the given block. The method
  #  returns <code>true</code> if the block never returns <code>true</code>
  #  for all elements. If the block is not given, <code>one?</code> will return
  #  <code>true</code> only if any of the collection members is true.
  #     
  #     %w{ant bear cat}.one? {|word| word.length == 4}   #=> true
  #     %w{ant bear cat}.one? {|word| word.length >= 4}   #=> false
  #     [ nil, true, 99 ].one?                            #=> true
  def none?(&prc)
    prc = lambda { |obj| obj } unless block_given?
    times = 0
    each { |o| times += 1 if prc.call(o) }
    times == 0
  end


  #  :call-seq:
  #     enum.min                    => obj
  #     enum.min {| a,b | block }   => obj
  #  
  #  Returns the object in <i>enum</i> with the minimum value. The
  #  first form assumes all objects implement <code>Comparable</code>;
  #  the second uses the block to return <em>a <=> b</em>.
  #     
  #     a = %w(albatross dog horse)
  #     a.min                                  #=> "albatross"
  #     a.min {|a,b| a.length <=> b.length }   #=> "dog"
  def min(&prc)
    prc = lambda { |a, b| a <=> b } unless block_given?
    min = nil
    each do |o|
      if min.nil?
        min = o
      else
        comp = prc.call(o, min)
        if comp.nil?
          raise ArgumentError, "comparison of #{o.class} with #{min} failed"
        elsif comp < 0
          min = o
        end
      end
    end
    min
  end


  #  :call-seq:
  #     enum.max                   => obj
  #     enum.max {|a,b| block }    => obj
  #  
  #  Returns the object in _enum_ with the maximum value. The
  #  first form assumes all objects implement <code>Comparable</code>;
  #  the second uses the block to return <em>a <=> b</em>.
  #     
  #     a = %w(albatross dog horse)
  #     a.max                                  #=> "horse"
  #     a.max {|a,b| a.length <=> b.length }   #=> "albatross"
  def max(&prc)
    prc = lambda { |a, b| a <=> b } unless block_given?
    max = nil
    each do |o|
      if max.nil?
        max = o
      else
        comp = prc.call(o, max)
        if comp.nil?
          raise ArgumentError, "comparison of #{o.class} with #{max} failed"
        elsif comp > 0
          max = o
        end
      end
    end
    max
  end

  #  :call-seq:
  #     enum.min_by {| obj| block }   => obj
  #  
  #  Returns the object in <i>enum</i> that gives the minimum
  #  value from the given block.
  #     
  #     a = %w(albatross dog horse)
  #     a.min_by {|x| x.length }   #=> "dog"
  def min_by
    min, min_value = nil, nil
    each do |o|
      o_value = yield(o)
      lesser = min.nil? || min_value <=> o_value > 0
      min, min_value = o, o_value if lesser
    end
    min
  end
  
  #  :call-seq:
  #     enum.max_by {| obj| block }   => obj
  #  
  #  Returns the object in <i>enum</i> that gives the maximum
  #  value from the given block.
  #     
  #     a = %w(albatross dog horse)
  #     a.max_by {|x| x.length }   #=> "albatross"
  def max_by
    max, max_value = nil, nil
    each do |o|
      o_value = yield(o)
      greater = max.nil? || (max_value <=> o_value) < 0
      max, max_value = o, o_value if greater
    end
    max
  end


  #  :call-seq:
  #     enum.include?(obj)     => true or false
  #     enum.member?(obj)      => true or false
  #  
  #  Returns <code>true</code> if any member of <i>enum</i> equals
  #  <i>obj</i>. Equality is tested using <code>obj.==</code>.
  #     
  #     IO.constants.include? "SEEK_SET"          #=> true
  #     IO.constants.include? "SEEK_NO_FURTHER"   #=> false
  #     
  def include?(obj)
    each { |o| return true if obj == o }
    false
  end

  alias_method :member?, :include?

  #  :call-seq:
  #     enum.each_with_index {|obj, i| block }  -> enum
  #  
  #  Calls <em>block</em> with two arguments, the item and its index, for
  #  each item in <i>enum</i>.
  #     
  #     hash = Hash.new
  #     %w(cat dog wombat).each_with_index {|item, index|
  #       hash[item] = index
  #     }
  #     hash   #=> {"cat"=>0, "wombat"=>2, "dog"=>1}
  def each_with_index
    idx = 0
    each { |o| yield(o, idx); idx += 1 }
    self
  end

  #  :call-seq:
  #     enum.zip(arg, ...)                   => array
  #     enum.zip(arg, ...) {|arr| block }    => nil
  #  
  #  Converts any arguments to arrays, then merges elements of
  #  <i>enum</i> with corresponding elements from each argument. This
  #  generates a sequence of <code>enum#size</code> <em>n</em>-element
  #  arrays, where <em>n</em> is one more that the count of arguments. If
  #  the size of any argument is less than <code>enum#size</code>,
  #  <code>nil</code> values are supplied. If a block given, it is
  #  invoked for each output array, otherwise an array of arrays is
  #  returned.
  #     
  #     a = [ 4, 5, 6 ]
  #     b = [ 7, 8, 9 ]
  #     
  #     (1..3).zip(a, b)      #=> [[1, 4, 7], [2, 5, 8], [3, 6, 9]]
  #     "cat\ndog".zip([1])   #=> [["cat\n", 1], ["dog", nil]]
  #     (1..3).zip            #=> [[1], [2], [3]]
  #     
  def zip(*args)
    result = []
    args = args.map { |a| a.to_a }
    each_with_index do |o, i|
      result << args.inject([o]) { |ary, a| ary << a[i] }
      yield(result.last) if block_given?
    end
    result unless block_given?
  end


end # module Enumerable

