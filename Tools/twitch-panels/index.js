import { parseArgs } from 'node:util';

const options = {
  id: {
    type: 'string',
    // short: 'id',
  },
};

const {
  values: args
} = parseArgs({ options });

const req = await fetch("https://gql.twitch.tv/gql#origin=twilight", {
    "credentials": "include",
    "headers": {
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/113.0",
        "Accept": "*/*",
        "Accept-Language": "en-US",
        "Client-Id": "kimne78kx3ncx6brgo4mv6wki5h1ko",
        "Content-Type": "text/plain;charset=UTF-8",
        "Sec-Fetch-Dest": "empty",
        "Sec-Fetch-Mode": "cors",
        "Sec-Fetch-Site": "same-site"
    },
    "referrer": "https://www.twitch.tv/",
    "body": `[{\"operationName\":\"ChannelPanels\",\"variables\":{\"id\":\"${args.id}\"},\"extensions\":{\"persistedQuery\":{\"version\":1,\"sha256Hash\":\"c388999b5fcd8063deafc7f7ad32ebd1cce3d94953c20bf96cffeef643327322\"}}}]`,
    "method": "POST",
    "mode": "cors"
});

const data = await req.json()
const panels =data[0]?.data?.user?.panels

if (!panels) {
	throw new Error('No panels')
}

console.log(panels)
