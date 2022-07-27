module ScheduleBot

using Dates: DateTime, Millisecond, UTC, now, @dateformat_str

using JSON3: JSON3
using Discorder
using TimeZones

const DATA_DIR = joinpath(@__DIR__, "..", "..", "data")
const DATETIME_FORMAT = "yyyy-mm-ddTHH:MM:SSz"
const LIVE_URL = "https://live.juliacon.org/"

D = Discorder

function load_channel(room)
    data = open(JSON3.read, joinpath(DATA_DIR, "discord.json"))
    filtered = filter(x -> x.name == room, data.channels)
    return (filtered[1].color, filtered[1].id)
end

function send_message(client::BotClient, bot_channels::Vector{DiscordChannel}, talk::JSON3.Object)
    @info "Alerting" now() talk.slot.room.en
    try
        color, id = load_channel(talk.slot.room.en)
        channel = filter(x -> x.id == id, bot_channels)[1]
        message = format_message(talk, color)
        D.create_message(client, channel; embeds=[message])
    catch ex
        @warn "Sending message failed" talk.slot.room.en ex
        try
            sleep(0.3)
            D.create_message(client, channel; embeds=[message])
            @info "Retry was successful" talk.slot.room.en
        catch ex2
            @warn "Retry failed also :-(" talk.slot.room.en ex2
        end
    end
end

function format_message(talk, color)
    description = talk.description
    if length(description) > 2000
        description = description[1:1994] * " [...]"
    end

    fields = [EmbedField(name="More info", value=LIVE_URL)]
    speakers = map(s -> s.name, talk.speakers)
    if !isempty(speakers)
        pushfirst!(fields, EmbedField(name="Presented by", value=join(speakers, ", ")))
    end

    embed = Embed(
        title = talk.title,
        description = description,
        author = EmbedAuthor(name="Starting now!"),
        color = color,
        fields = fields,
    )

    if talk.image !== nothing
        embed.thumbnail = EmbedThumbnail(url=talk.image)
    end

    return embed
end

function updater(client::BotClient, bot_channels::Vector{DiscordChannel})
    @info "Starting updater at:" now()
    try
        while true
            current_time = now(localzone())
            all_talks = retry(load_talks; delays=fill(0.2, 3))()
            for (start, talks) in all_talks
                wait = start - current_time
                wait < Millisecond(0) && continue
                @info "Talks Loaded" current_time start wait length(all_talks)
                if wait > Millisecond(600000)
                    @info "Sleeping for 60 seconds"
                    sleep(60)
                    break
                end
                @info "Waiting until next block"
                sleep(div(wait.value, 1000))
                for talk in talks
                    @info "Sending message" talk.title
                    send_message(client, bot_channels, talk)
                    sleep(0.3)
                end
            end
        end
    catch ex
        @info "updater stopped due to $(ex)" now()
        return nothing
    end
end

function load_talks()
    talks = open(JSON3.read, joinpath(DATA_DIR, "talks.json"))
    buckets = Dict{ZonedDateTime, Vector{JSON3.Object}}()
    for talk in talks
        start = ZonedDateTime(talk.slot.start, DATETIME_FORMAT)
        push!(get!(() -> [], buckets, start), talk)
    end
    return sort(collect(buckets); by=first)
end

function run()
    bot_client = D.BotClient()
    channels = D.get_guild_channels(bot_client, D.get_current_user_guilds(bot_client)[1])

    @info "Connected to client"

    updater(bot_client, channels)

    @info "Disconnected Discord client"

    return nothing

end

end
