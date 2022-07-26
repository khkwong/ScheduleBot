using ScheduleBot
using HTTP
using Dates
using JSON3

const DATA_DIR = joinpath(@__DIR__, "..", "..", "data")

function fetch()
    try
        while true
            @info "Starting fetch" now()
            req = HTTP.get("https://raw.githubusercontent.com/JuliaCon/juliacon-webapp/master/data/talks.json")
            new_data = String(req.body)
            open(joinpath(DATA_DIR, "talks.json"), "w") do io
                JSON3.pretty(io, new_data)
            end
            @info "Sleeping for 5 minutes"
            sleep(300)
        end
    catch ex
        @warn "Fetching failed" exception=(ex, catch_backtrace())
    end
end

fetch()
