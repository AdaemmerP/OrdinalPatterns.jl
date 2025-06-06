
@testset "check frequencies" begin

    # lookup_array_sop = compute_lookup_array_sop()
    # n_sops = 24
    # sop = zeros(4)
    # data = [9 1 2; 
    #         6 7 6; 
    #         9 4 9]
    # m = size(data, 1) - 1
    # n = size(data, 2) - 1
    # win = zeros(Int, 4)

    # # Check ranks    
    # order_vec!([data[1, 1], data[1, 2], data[2, 1], data[2, 2]], win) 
    # @test win == [2, 3, 4, 1]
    # order_vec!([data[2, 1], data[2, 2], data[3, 1], data[3, 2]], win) 
    # @test win == [4, 1, 2, 3]
    # order_vec!([data[1, 2], data[1, 3], data[2, 2], data[2, 3]], win)  
    # @test win == [1, 2, 4, 3]
    # order_vec!([data[2, 2], data[2, 3], data[3, 2], data[3, 3]], win)
    # @test win == [3, 2, 1, 4]

    # # run sop_frequencies
    # test_freq = sop_frequencies(m, n, lookup_array_sop, n_sops, data, sop)
    # @test sum(findall(test_freq .== 1) .== [2, 10, 15, 19]) == 4

  # Original groups (not refined) as in Adämmer et al (2014)  
    s1_rank = [1 2 3 4;
        1 3 2 4;
        2 1 4 3;
        2 4 1 3;
        3 1 4 2;
        3 4 1 2;
        4 2 3 1;
        4 3 2 1]

    s2_rank = [1 2 4 3;
        1 4 2 3;
        2 1 3 4;
        2 3 1 4;
        3 2 4 1;
        3 4 2 1;
        4 1 3 2;
        4 3 1 2
    ]

    s3_rank = [1 3 4 2;
        1 4 3 2;
        2 3 4 1;
        2 4 3 1;
        3 1 2 4;
        3 2 1 4;
        4 1 2 3;
        4 2 1 3
    ]

    # Check all ranks
    lookup_ranks = collect(permutations(1:4)) # same approach as in sop_help functions
    lookup_array_sop = compute_lookup_array_sop()

    # Group indices of vector entry
    s_1 = (1, 3, 8, 11, 14, 17, 22, 24)
    s_2 = (2, 5, 7, 9, 16, 18, 20, 23)
    s_3 = (4, 6, 10, 12, 13, 15, 19, 21)

    # Check conversion from rank to order
    for i in 24
        index = sortperm(lookup_ranks[i])
        @test lookup_array_sop[index[1], index[2], index[3], index[4]] == i
    end

    # Check first group
    for (i, j) in enumerate(s_1)
        index = sortperm(s1_rank[i, :]) 
        @test lookup_array_sop[index[1], index[2], index[3], index[4]] == j
    end

    # Check second group
    for (i, j) in enumerate(s_2)
        index = sortperm(s2_rank[i, :]) 
        @test lookup_array_sop[index[1], index[2], index[3], index[4]] == j
    end

    # Check third group
    for (i, j) in enumerate(s_3)
        index = sortperm(s3_rank[i, :]) 
        @test lookup_array_sop[index[1], index[2], index[3], index[4]] == j
    end

end
