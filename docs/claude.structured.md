Prompt engineering
Use XML tags to structure your prompts
When your prompts involve multiple components like context, instructions, and examples, XML tags can be a game-changer. They help Claude parse your prompts more accurately, leading to higher-quality outputs.

XML tip: Use tags like <instructions>, <example>, and <formatting> to clearly separate different parts of your prompt. This prevents Claude from mixing up instructions with examples or context.
​
Why use XML tags?
Clarity: Clearly separate different parts of your prompt and ensure your prompt is well structured.
Accuracy: Reduce errors caused by Claude misinterpreting parts of your prompt.
Flexibility: Easily find, add, remove, or modify parts of your prompt without rewriting everything.
Parseability: Having Claude use XML tags in its output makes it easier to extract specific parts of its response by post-processing.
There are no canonical "best" XML tags that Claude has been trained with in particular, although we recommend that your tag names make sense with the information they surround.
There are no canonical “best” XML tags that Claude has been trained with in particular, although we recommend that your tag names make sense with the information they surround.
​
Tagging best practices
Be consistent: Use the same tag names throughout your prompts, and refer to those tag names when talking about the content (e.g, Using the contract in <contract> tags...).
Nest tags: You should nest tags <outer><inner></inner></outer> for hierarchical content.

How to get consistent structured output from Claude

#

ai

#

typescript

#

tutorial
Using Anthropic's excellent Claude models in automated workflows can be tricky. Although they excel at conversational interaction, getting consistently formatted output that can be used programmatically requires some work. Unlike OpenAI's models, Claude does not have an option to request structured data, but it is possible with a simple trick.

In this tutorial we'll build a reusable component that calls Claude Haiku and returns structured data following a schema. We'll then use this component to create a workflow for checking user comments for inappropriate content.

This tutorial assumes you are familiar with Node.js and TypeScript.

LLM output is hard to parse
Large Language Models (LLMs) bias towards responding in human readable text and tend to be verbose, often giving additional context even when asked for specific output. This is great for casual chats, but becomes a problem when we try to use LLM responses in workflows where the output feeds into subsequent tasks and needs to be parsed programmatically.

For example, we might to use an LLM to sort customer support messages by category and urgency. To label the messages correctly we would need the LLM to return the category title and urgency score on a predefined scale. This could be achieved by custom prompts requesting a structured response, but there is no guarantee the model will follow the instructions for the output exactly.

Utilising Tool Use to get structured data
Fortunately there is a simple trick we can use to get consistent structured output from Anthropic's Claude models: create a tool spec for Claude with a defined input schema and force the model to use this tool. This will ensure the response follows the specified format. We can generate this input schema using Zod, a TypeScript-first schema library, which we can also use to validate the LLM output and infer TypeScript types.

Setting up the project
Before we write any code, we need to do some set up.

Creating an account with Anthropic
To make calls to the Anthropic API, you will need to create an account on the Anthropic API console and add some credit. Five USD will be more than enough for this tutorial.

Creating project folder
Create a folder for the project and change the current working directory to this folder.

mkdir claude-structured-output && cd claude-structured-output
Installing dependencies
Install pnpm if you don't have it already. You can install it using Corepack which is included with Node.js.

corepack enable pnpm
Then initialise pnpm and install the required dependencies.

pnpm init && pnpm add @anthropic-ai/sdk dotenv && pnpm add -D @types/node
Setting up env variables and TypeScript config
Create an file to safely store env variables and add your Anthropic API key, which you can find in the Anthropic console.

echo "ANTHROPIC_API_KEY=[YOUR API KEY HERE]" > .env
We'll also add some basic configuration for TypeScript. First create the config file.

touch tsconfig.json
Then add the following rules to tsconfig.json.

{
"compilerOptions": {
"module": "esnext",
"moduleResolution": "node",
"esModuleInterop": true,
"target": "esnext",
"types": ["node"]
},
"include": ["**/*.ts"]
}
Making a request
Before we look into using a schema for structured output, let's create a basic component and a workflow script to make an LLM call. We can inspect the result and see why specifying a consistently structured output would be useful.

Creating a basic component for LLM calls
Now that the project has been set up, we can create a class to call the Anthropic API. The class constructor creates a new client, which we can then use to send messages to the API via the call function.

touch model.ts
// model.ts

import Anthropic from "@anthropic-ai/sdk";

export default class Model {
private client: Anthropic;

constructor(apiKey: string) {
this.client = new Anthropic({ apiKey });
}

async call(message: string) {
console.log("[LLM] Getting LLM API response");
const response = await this.client.messages.create({
max_tokens: 1024,
model: "claude-3-5-haiku-latest",
messages: [{ role: "user", content: message }],
temperature: 0, // minimal randomness injected into the response
});

    const result = response.content[0];

    return result.type === "text" ? result.text : result.input;

}
}
Using the component to analyse a message
We can instantiate the class, send a message to the API and log the output to see what it looks like. Note that because we're using an LLM to analyse the messages, our criteria for what is and isn't appropriate can easily be customised to fit our needs.

touch main.ts
// main.ts

import "dotenv/config";
import Model from "./model";

const instructions =
"Check the following comment for inappropriate content, meaning foul language, harassment, or anti-union sentiment. If such content is detected, specify the type(s) of inappropriate content, explain the reasoning behind the assessment, and provide a confidence score.";

const comment =
"These idiots deserve it. Should have spent more time working and less time on TikTok";

const model = new Model(process.env.ANTHROPIC_API_KEY || "");

const response = await model.call(`${instructions}\n\n${comment}`);

console.log("[Main] Comment analysed: ", {
message: comment,
response,
});
Inspecting the output
Run the project and have a look at the output.

npx tsx main.ts
You will see that although we get a detailed and likely correct analysis in response, the format of the response is unpredictable and would require a human (or an LLM) to parse. This is not great if we want to use the response to take some automatic actions such a removing or labelling inappropriate posts. To get a response in a more useful format, let's give Claude a tool to use.

Requesting a structured response
Managing output structure using a schema
First we'll add the Zod library, and a library to generate JSON schemas from Zod schemas.

pnpm add zod zod-to-json-schema
Now update the model to accept a Zod schema. The tool input specification requires a JSON schema, which we can generate from the Zod schema. Then we pass the tool spec as an argument in the LLM API call, along with the tool_choice parameter, telling Claude to use our tool. When we receive a response we can use the Zod schema to check if it conforms to the expected format and throw an error if it doesn't. Finally, we can infer the type from the Zod schema and assert the return type of the call.

// model.ts

import Anthropic from "@anthropic-ai/sdk";
import type { Tool } from "@anthropic-ai/sdk/resources/index";
import { z } from "zod";
import { zodToJsonSchema } from "zod-to-json-schema";

export default class Model {
private client: Anthropic;

constructor(apiKey: string) {
this.client = new Anthropic({ apiKey });
}

async call<T extends z.ZodTypeAny>({
message,
schema,
}: {
message: string;
schema: T;
}) {
const jsonSchema = zodToJsonSchema(schema, "schema");
const schemaDefinition = jsonSchema.definitions?.schema;

    if (!schemaDefinition) {
      console.error(jsonSchema);
      throw new Error("Failed to generate JSON schema for provided schema.");
    }

    const tools = [
      {
        name: "json",
        description: "Respond with a JSON object.",
        input_schema: schemaDefinition as Tool.InputSchema,
      },
    ];

    console.log("[LLM] Getting LLM API response");
    const response = await this.client.messages.create({
      max_tokens: 1024,
      model: "claude-3-5-haiku-latest",
      messages: [{ role: "user", content: message }],
      tools,
      tool_choice: { name: "json", type: "tool" },
      temperature: 0,
    });

    if (response.content[0]?.type !== "tool_use") {
      console.error(response);
      throw new Error("Unexpected response from LLM API.");
    }

    const result = schema.safeParse(response.content[0].input);

    if (result.success === false) {
      console.error(result.error);
      throw new Error("Response did not conform to provided schema.");
    }

    return result.data as z.infer<T>;

}
}
Defining and passing the schema
We'll need to add the schema and update the model call in the main function. We'll ask the model to flag if the content is inappropriate, give the reason for the assessment so it can be checked by a human if needed and tell us how confident it is in the assessment. We'll also ask it to return the type of violations committed. Let's also add a few more comments to analyse and loop over them, making a call for each one.

// main.ts

import "dotenv/config";
import { z } from "zod";
import Model from "./model";

const comments = [
"This company is a f*cking joke. They just announced record profits and now they’re firing people??",
"These layoffs are long overdue. The unions have made people lazy and complacent.",
"I went through layoffs last year and it was a horrible time for me and my family.",
"These idiots deserve it. Should have spent more time working and less time on TikTok",
];

const schema = z.object({
isInappropriateContent: z.boolean(),
reason: z.string(),
confidence: z.number().min(0).max(1),
type: z.object({
foulLanguage: z.boolean(),
harassment: z.boolean(),
antiUnionSentiment: z.boolean(),
}),
});

const instructions =
"Check the following comment for inappropriate content, meaning foul language, harassment, or anti-union sentiment. If such content is detected, specify the type(s) of inappropriate content, explain the reasoning behind the assessment, and provide a confidence score.";

const model = new Model(process.env.ANTHROPIC_API_KEY || "");

for (const comment of comments) {
const response = await model.call({
message: `${instructions}\n\n${comment}`,
schema,
});

console.log("[Main] Comment analysed: ", {
message: comment,
response,
});
}
Inspecting structured output
Run the project again. You should be getting consistently formatted JSON output for each analysed comment.

npx tsx main.ts
Conclusion
Now we have a simple and reliable way to get consistent JSON output from Claude, which enables us to integrate LLM calls into automated workflows.

Key takeaways:
Default LLM responses are great for conversational interaction, but hard to parse programmatically, making them unsuitable for automated workflows.
By specifying a JSON schema as the input for a tool and instructing Claude to use that tool, we can consistently get output conforming to our required structure.
Using Zod we can specify schemas, validate response structure and get correctly typed return values, improving confidence and developer experience.

Enforcing JSON outputs in commercial LLMs
A comprehensive guide

Daniel Kharitonov
Aug 28, 2024
11 min read
Share
TL;DR

We tested the structured output capabilities of Google Gemini Pro, Anthropic Claude, and OpenAI GPT. In their best-performing configurations, all three models can generate structured outputs on a scale of thousands of JSON objects. However, the API capabilities vary significantly in the effort required to prompt the models to produce JSONs and in ability to adhere to the data models.

More specifically, the only commercial vendor offering consistent structured outputs right out of the box appears to be OpenAI, with their latest Structured Outputs API released on August 6th, 2024. OpenAI’s GPT-4o can directly integrate with Pydantic data models, formatting JSONs based on the required fields and field descriptions.

Anthropic’s Claude Sonnet 3.5 takes second place because it requires a ‘tool call’ trick to reliably produce JSONs. While Claude can interpret field descriptions, it does not directly support Pydantic models.

Finally, Google Gemini 1.5 Pro ranks third due to its cumbersome API, which requires the use of the poorly documented genai.protos.Schema class as a model for reliable JSON production. Additionally, there appears to be no straightforward way to guide Gemini’s output using field descriptions.

Here are the test results in a summary table:

Approximate rates of structured output errors (data source: author's Jupyter notebook below)
Approximate rates of structured output errors (data source: author’s Jupyter notebook below)
Here is the link to the testbed notebook:

https://github.com/iterative/datachain-examples/blob/main/formats/JSON-outputs.ipynb

Introduction to the problem

The ability to generate structured output from an LLM is not critical when it’s used as a generic chatbot. However, structured outputs become indispensable in two emerging LLM applications:

• LLM-based analytics (such as AI-driven judgments and unstructured data analysis)

• Building LLM agents

In both cases, it’s crucial that the communication from an LLM adheres to a well-defined format. Without this consistency, downstream applications risk receiving inconsistent inputs, leading to potential errors.

Unfortunately, while most modern LLMs offer methods designed to produce structured outputs (such as JSON), these methods often encounter two significant issues:

They periodically fail to produce a valid structured object.
They generate a valid object but cannot adhere to the requested data model.
In the following text, we document our findings on the structured output capabilities of the latest offerings from Anthropic Claude, Google Gemini, and OpenAI’s GPT.

Anthropic Claude Sonnet 3.5

At first glance, Anthropic Claude’s API looks straightforward because it features a section titled ‘Increasing JSON Output Consistency,’ which opens with an example of a moderately complex structured output:

import os
import anthropic

PROMPT = """
You're a Customer Insights AI.
Analyze this feedback and output in JSON format with keys: "sentiment" (positive/negative/neutral),
"key_issues" (list), and "action_items" (list of dicts with "team" and "task").
"""

source_files = "gs://datachain-demo/chatbot-KiT/"
client = anthropic.Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))

completion = (
client.messages.create(  
 model="claude-3-5-sonnet-20240620",
max_tokens = 1024,  
 system=PROMPT,  
 messages=[{"role": "user", "content": "User: Book me a ticket. Bot: I do not know."}]
)
)
print(completion.content[0].text)
However, if we actually run this code a few times, we will notice that conversion to JSON fails because the LLM prepends JSON object with an unwanted text prefix:

Here's the analysis of that feedback in JSON format:

{
"sentiment": "negative",
"key_issues": [
"Bot unable to perform requested task",
"Lack of functionality",
"Poor user experience"
],
"action_items": [
{
"team": "Development",
"task": "Implement ticket booking functionality"
},
{
"team": "Knowledge Base",
"task": "Create and integrate a database of ticket booking information and procedures"
},
{
"team": "UX/UI",
"task": "Design a user-friendly interface for ticket booking process"
},
{
"team": "Training",
"task": "Improve bot's response to provide alternatives or direct users to appropriate resources when unable to perform a task"
}
]
}
This issue affects approximately 14–20% of requests, making reliance on Claude’s ‘structured prompt’ feature questionable. The problem is evidently well-known to Anthropic, as their documentation provides two more recommendations:

Provide inline examples of valid output.
Coerce the LLM to begin its response with a valid preamble.
The second solution is somewhat inelegant, as it requires pre-filling the response and then recombining it with the generated output afterward.

Here’s an example of code that implements both techniques and evaluates the validity of a resulting JSON string. This prompt was tested across 50 different dialogs by Karlsruhe Institute of Technology using Iterative’s DataChain library:

import os
import json
import anthropic
from datachain import File, DataChain, Column

source_files = "gs://datachain-demo/chatbot-KiT/"
client = anthropic.Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))

PROMPT = """
You're a Customer Insights AI.
Analyze this dialog and output in JSON format with keys: "sentiment" (positive/negative/neutral),
"key_issues" (list), and "action_items" (list of dicts with "team" and "task").

Example:
{
"sentiment": "negative",
"key_issues": [
"Bot unable to perform requested task",
"Poor user experience"
],
"action_items": [
{
"team": "Development",
"task": "Implement ticket booking functionality"
},
{
"team": "UX/UI",
"task": "Design a user-friendly interface for ticket booking process"
}
]
}  
"""
prefill='{"sentiment":'

def eval_dialogue(file: File) -> str:  
 completion = (
client.messages.create(  
 model="claude-3-5-sonnet-20240620",
max_tokens = 1024,  
 system=PROMPT,  
 messages=[{"role": "user", "content": file.read()},
{"role": "assistant", "content": f'{prefill}'},
]
)
)
json_string = prefill + completion.content[0].text
try: # Attempt to convert the string to JSON
json_data = json.loads(json_string)
return json_string
except json.JSONDecodeError as e: # Catch JSON decoding errors
print(f"JSONDecodeError: {e}")
print(json_string)
return json_string

chain = DataChain.from_storage(source_files, type="text")  
 .filter(Column("file.path").glob("\*.txt"))  
 .map(claude = eval_dialogue)  
 .exec()
The results have improved, but they are still not perfect. Approximately one out of every 50 calls returns an error:

JSONDecodeError: Expecting value: line 2 column 1 (char 14)
{"sentiment":
Human: I want you to analyze the conversation I just shared
This implies that the Sonnet 3.5 model may fail to follow the instructions and hallucinate unwanted continuations of the dialogue. As a result, the model is still not consistently adhering to desired outputs.

Fortunately, there’s another approach to explore within the Claude API: utilizing function calls. These functions, referred to as ‘tools’ in Anthropic’s API, inherently require structured input to operate. To leverage this option, we can create a mock function and configure the call signature identical with our desired JSON object:

import os
import json
import anthropic
from datachain import File, DataChain, Column

from pydantic import BaseModel, Field, ValidationError
from typing import List, Optional

class ActionItem(BaseModel):
team: str
task: str

class EvalResponse(BaseModel):
sentiment: str = Field(description="dialog sentiment (positive/negative/neutral)")
key_issues: list[str] = Field(description="list of five problems discovered in the dialog")
action_items: list[ActionItem] = Field(description="list of dicts with 'team' and 'task'")

source_files = "gs://datachain-demo/chatbot-KiT/"
client = anthropic.Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))

PROMPT = """
You're assigned to evaluate this chatbot dialog and sending the results to the manager via send_to_manager tool.  
"""

def eval_dialogue(file: File) -> str:  
 completion = (
client.messages.create(  
 model="claude-3-5-sonnet-20240620",
max_tokens = 1024,  
 system=PROMPT,
tools=[
{
"name": "send_to_manager",
"description": "Send bot evaluation results to a manager",
"input_schema": EvalResponse.model_json_schema(),
}
],
messages=[{"role": "user", "content": file.read()},
]
)
)
try: # We are only interested in the ToolBlock part
json_dict = completion.content[1].input
except IndexError as e: # Catch cases where Claude refuses to use tools
print(f"IndexError: {e}")
print(completion)
return str(completion)
try: # Attempt to convert the tool dict to EvalResponse object
EvalResponse(\*\*json_dict)
return completion
except ValidationError as e: # Catch Pydantic validation errors
print(f"Pydantic error: {e}")
print(completion)
return str(completion)

tool_chain = DataChain.from_storage(source_files, type="text")  
 .filter(Column("file.path").glob("\*.txt"))  
 .map(claude = eval_dialogue)  
 .exec()
After running this code 50 times, we encountered one erratic response, which looked like this:

IndexError: list index out of range
Message(id='msg_018V97rq6HZLdxeNRZyNWDGT',
content=[TextBlock(
text="I apologize, but I don't have the ability to directly print anything.
I'm a chatbot designed to help evaluate conversations and provide analysis.
Based on the conversation you've shared,
it seems you were interacting with a different chatbot.
That chatbot doesn't appear to have printing capabilities either.
However, I can analyze this conversation and send an evaluation to the manager.
Would you like me to do that?", type='text')],
model='claude-3-5-sonnet-20240620',
role='assistant',
stop_reason='end_turn',
stop_sequence=None, type='message',
usage=Usage(input_tokens=1676, output_tokens=95))
In this instance, the model became confused and failed to execute the function call, instead only returning a text block and stopping prematurely (with stop_reason = ‘end_turn’). Fortunately, the Claude API offers a solution to prevent this behavior and force the model to always emit a tool call rather than a text block. By adding the following line to the configuration, you can ensure the model adheres to the intended function call behavior:

tool_choice = {"type": "tool", "name": "send_to_manager"}
After forcing the tool choice, Claude Sonnet 3.5 was able to successfully return a valid JSON object over 1,000 times without any errors. And if you’re not interested in building this function call yourself, LangChain provides an Anthropic wrapper that simplifies the process with an easy-to-use call format:

from langchain_anthropic import ChatAnthropic

model = ChatAnthropic(model="claude-3-opus-20240229", temperature=0)
structured_llm = model.with_structured_output(Joke)
structured_llm.invoke("Tell me a joke about cats. Make sure to call the Joke function.")
As an added bonus, Claude seems to interpret field descriptions effectively. This means that if you’re dumping a JSON schema from a Pydantic class defined like this..

class EvalResponse(BaseModel):
sentiment: str = Field(description="dialog sentiment (positive/negative/neutral)")
key_issues: list[str] = Field(description="list of five problems discovered in the dialog")
action_items: list[ActionItem] = Field(description="list of dicts with 'team' and 'task'")
…then you might actually receive an object that follows your desired description.

Reading the field descriptions for a data model is a very useful thing because it allows us to specify the nuances of the desired response without touching the model prompt.

Google Gemini Pro 1.5

Google’s documentation clearly states that prompt-based methods for generating JSON are unreliable and restricts more advanced configurations – such as using an OpenAPI schema – to the flagship Gemini Pro model family. Indeed, the prompt-based performance of Gemini for JSON output is rather poor. When simply asked for a JSON, the model routinely wraps the output in a Markdown preamble:

```json
{
  "sentiment": "negative",
  "key_issues": [
    "Bot misunderstood user confirmation.",
    "Recommended plan doesn't meet user needs (more MB, less minutes, price limit)."
  ],
  "action_items": [
    {
      "team": "Engineering",
      "task": "Investigate why bot didn't understand 'correct' and 'yes it is' confirmations."
    },
    {
      "team": "Product",
      "task": "Review and improve plan matching logic to prioritize user needs and constraints."
    }
  ]
}
To combat this, a more refined configuration unlocks Gemini’s "JSON mode" by specifying the output mime type:

generation_config={"response_mime_type": "application/json"}
However, this tricks also fails to work reliably because once in a while the model still fails to return a parseable JSON string.

Returning to Google’s original recommendation, one might assume that upgrading to their premium model and using the responseSchema parameter should guarantee reliable JSON outputs.

Unfortunately, the reality is more complex. Google offers multiple ways to configure the responseSchema – by providing an OpenAPI model, an instance of a user class, or a reference to Google’s proprietary genai.protos.Schema.

While all these methods are effective at generating valid JSONs, it is only the latter that guarantees the model emits all ‘required’ fields. This limitation forces users to define their data models twice – as Pydantic and genai.protos.Schema objects – while also losing the ability to convey additional information to the model through field descriptions:

class ActionItem(BaseModel):
    team: str
    task: str

class EvalResponse(BaseModel):
    sentiment: str = Field(description="dialog sentiment (positive/negative/neutral)")
    key_issues: list[str] = Field(description="list of 3 problems discovered in the dialog")
    action_items: list[ActionItem] = Field(description="list of dicts with 'team' and 'task'")

g_str = genai.protos.Schema(type=genai.protos.Type.STRING)

g_action_item = genai.protos.Schema(
            type=genai.protos.Type.OBJECT,
            properties={
                'team':genai.protos.Schema(type=genai.protos.Type.STRING),
                'task':genai.protos.Schema(type=genai.protos.Type.STRING)
            },
            required=['team','task']
        )

g_evaluation=genai.protos.Schema(
            type=genai.protos.Type.OBJECT,
            properties={
                'sentiment':genai.protos.Schema(type=genai.protos.Type.STRING),
                'key_issues':genai.protos.Schema(type=genai.protos.Type.ARRAY, items=g_str),
                'action_items':genai.protos.Schema(type=genai.protos.Type.ARRAY, items=g_action_item)
            },
            required=['sentiment','key_issues', 'action_items']
        )

def gemini_setup():
    genai.configure(api_key=google_api_key)
    return genai.GenerativeModel(model_name='gemini-1.5-pro-latest',
                                 system_instruction=PROMPT,
                                 generation_config={"response_mime_type": "application/json",
                                                     "response_schema": g_evaluation,
                                                   }
                                )
OpenAI GPT-4o

Among the three Llm providers we’ve examined, OpenAI offers the most flexible solution with the simplest configuration. Their "Structured Outputs API" can directly accept a Pydantic model, enabling it to read both the data model and field descriptions effortlessly:

class Suggestion(BaseModel):
    suggestion: str = Field(description="Suggestion to improve the bot, starting with letter K")

class Evaluation(BaseModel):
    outcome: str = Field(description="whether a dialog was successful, either Yes or No")
    explanation: str = Field(description="rationale behind the decision on outcome")
    suggestions: list[Suggestion] = Field(description="Six ways to improve a bot")

    @field_validator("outcome")
    def check_literal(cls, value):
        if not (value in ["Yes", "No"]):
            print(f"Literal Yes/No not followed: {value}")
        return value

    @field_validator("suggestions")
    def count_suggestions(cls, value):
        if len(value) != 6:
            print(f"Array length of 6 not followed: {value}")
        count = sum(1 for item in value if item.suggestion.startswith('K'))
        if len(value) != count:
            print(f"{len(value)-count} suggestions don't start with K")
        return value

def eval_dialogue(client, file: File) -> Evaluation:
     completion = client.beta.chat.completions.parse(
         model="gpt-4o-2024-08-06",
         messages=[
            {"role": "system", "content": prompt},
            {"role": "user", "content": file.read()},
         ],
         response_format=Evaluation,
     )
In terms of robustness, OpenAI documentation references a graph comparing the success rates of their ‘Structured Outputs’ API versus prompt-based solutions, with the former achieving a success rate very close to 100%.

However, the devil is in the details.

While OpenAI’s JSON performance is ‘close to 100%’, it is not entirely bulletproof. Even with a perfectly configured request, we found that a broken JSON still occurs in about one out of every few thousand calls – especially if the prompt is not carefully crafted, and would warrant a retry.

Despite this limitation, it is fair to say that, as of now, OpenAI offers the best solution for structured LLM output applications.

Note: the author is not affiliated with OpenAI, Anthropic or Google, but actively contributes to open-source development of LLM orchestration and evaluation tools.



```

Extracting Structured JSON using Claude and Tool Use
In this cookbook, we'll explore various examples of using Claude and the tool use feature to extract structured JSON data from different types of input. We'll define custom tools that prompt Claude to generate well-structured JSON output for tasks such as summarization, entity extraction, sentiment analysis, and more.

If you want to get structured JSON data without using tools, take a look at our "How to enable JSON mode" cookbook.

Set up the environment
First, let's install the required libraries and set up the Anthropic API client.

%pip install anthropic requests beautifulsoup4
from anthropic import Anthropic
import requests
from bs4 import BeautifulSoup
import json

client = Anthropic()
MODEL_NAME = "claude-3-haiku-20240307"
Example 1: Article Summarization
In this example, we'll use Claude to generate a JSON summary of an article, including fields for the author, topics, summary, coherence score, persuasion score, and a counterpoint.

tools = [
{
"name": "print_summary",
"description": "Prints a summary of the article.",
"input_schema": {
"type": "object",
"properties": {
"author": {"type": "string", "description": "Name of the article author"},
"topics": {
"type": "array",
"items": {"type": "string"},
"description": 'Array of topics, e.g. ["tech", "politics"]. Should be as specific as possible, and can overlap.'
},
"summary": {"type": "string", "description": "Summary of the article. One or two paragraphs max."},
"coherence": {"type": "integer", "description": "Coherence of the article's key points, 0-100 (inclusive)"},
"persuasion": {"type": "number", "description": "Article's persuasion score, 0.0-1.0 (inclusive)"}
},
"required": ['author', 'topics', 'summary', 'coherence', 'persuasion', 'counterpoint']
}
}
]

url = "https://www.anthropic.com/news/third-party-testing"
response = requests.get(url)
soup = BeautifulSoup(response.text, "html.parser")
article = " ".join([p.text for p in soup.find_all("p")])

query = f"""

<article>
{article}
</article>

Use the `print_summary` tool.
"""

response = client.messages.create(
model=MODEL_NAME,
max_tokens=4096,
tools=tools,
messages=[{"role": "user", "content": query}]
)
json_summary = None
for content in response.content:
if content.type == "tool_use" and content.name == "print_summary":
json_summary = content.input
break

if json_summary:
print("JSON Summary:")
print(json.dumps(json_summary, indent=2))
else:
print("No JSON summary found in the response.")
JSON Summary:
{
"author": "Anthropic",
"topics": [
"AI policy",
"AI safety",
"third-party testing"
],
"summary": "The article argues that the AI sector needs effective third-party testing for frontier AI systems to avoid societal harm, whether deliberate or accidental. It discusses what third-party testing looks like, why it's needed, and the research Anthropic has done to arrive at this policy position. The article states that such a testing regime is necessary because frontier AI systems like large-scale generative models don't fit neatly into use-case and sector-specific frameworks, and can pose risks of serious misuse or AI-caused accidents. Though Anthropic and other organizations have implemented self-governance systems, the article argues that industry-wide third-party testing is ultimately needed to be broadly trusted. The article outlines key components of an effective third-party testing regime, including identifying national security risks, and discusses how it could be accomplished by a diverse ecosystem of organizations. Anthropic plans to advocate for greater funding and public sector infrastructure for AI testing and evaluation, as well as developing tests for specific capabilities.",
"coherence": 90,
"persuasion": 0.8
}
Example 2: Named Entity Recognition
In this example, we'll use Claude to perform named entity recognition on a given text and return the entities in a structured JSON format.

tools = [
{
"name": "print_entities",
"description": "Prints extract named entities.",
"input_schema": {
"type": "object",
"properties": {
"entities": {
"type": "array",
"items": {
"type": "object",
"properties": {
"name": {"type": "string", "description": "The extracted entity name."},
"type": {"type": "string", "description": "The entity type (e.g., PERSON, ORGANIZATION, LOCATION)."},
"context": {"type": "string", "description": "The context in which the entity appears in the text."}
},
"required": ["name", "type", "context"]
}
}
},
"required": ["entities"]
}
}
]

text = "John works at Google in New York. He met with Sarah, the CEO of Acme Inc., last week in San Francisco."

query = f"""
<document>
{text}
</document>

Use the print_entities tool.
"""

response = client.messages.create(
model=MODEL_NAME,
max_tokens=4096,
tools=tools,
messages=[{"role": "user", "content": query}]
)

json_entities = None
for content in response.content:
if content.type == "tool_use" and content.name == "print_entities":
json_entities = content.input
break

if json_entities:
print("Extracted Entities (JSON):")
print(json_entities)
else:
print("No entities found in the response.")
Extracted Entities (JSON):
{'entities': [{'name': 'John', 'type': 'PERSON', 'context': 'John works at Google in New York.'}, {'name': 'Google', 'type': 'ORGANIZATION', 'context': 'John works at Google in New York.'}, {'name': 'New York', 'type': 'LOCATION', 'context': 'John works at Google in New York.'}, {'name': 'Sarah', 'type': 'PERSON', 'context': 'He met with Sarah, the CEO of Acme Inc., last week in San Francisco.'}, {'name': 'Acme Inc.', 'type': 'ORGANIZATION', 'context': 'He met with Sarah, the CEO of Acme Inc., last week in San Francisco.'}, {'name': 'San Francisco', 'type': 'LOCATION', 'context': 'He met with Sarah, the CEO of Acme Inc., last week in San Francisco.'}]}
Example 3: Sentiment Analysis
In this example, we'll use Claude to perform sentiment analysis on a given text and return the sentiment scores in a structured JSON format.

tools = [
{
"name": "print_sentiment_scores",
"description": "Prints the sentiment scores of a given text.",
"input_schema": {
"type": "object",
"properties": {
"positive_score": {"type": "number", "description": "The positive sentiment score, ranging from 0.0 to 1.0."},
"negative_score": {"type": "number", "description": "The negative sentiment score, ranging from 0.0 to 1.0."},
"neutral_score": {"type": "number", "description": "The neutral sentiment score, ranging from 0.0 to 1.0."}
},
"required": ["positive_score", "negative_score", "neutral_score"]
}
}
]

text = "The product was okay, but the customer service was terrible. I probably won't buy from them again."

query = f"""
<text>
{text}
</text>

Use the print_sentiment_scores tool.
"""

response = client.messages.create(
model=MODEL_NAME,
max_tokens=4096,
tools=tools,
messages=[{"role": "user", "content": query}]
)

json_sentiment = None
for content in response.content:
if content.type == "tool_use" and content.name == "print_sentiment_scores":
json_sentiment = content.input
break

if json_sentiment:
print("Sentiment Analysis (JSON):")
print(json.dumps(json_sentiment, indent=2))
else:
print("No sentiment analysis found in the response.")
Sentiment Analysis (JSON):
{
"negative_score": 0.6,
"neutral_score": 0.3,
"positive_score": 0.1
}
Example 4: Text Classification
In this example, we'll use Claude to classify a given text into predefined categories and return the classification results in a structured JSON format.

tools = [
{
"name": "print_classification",
"description": "Prints the classification results.",
"input_schema": {
"type": "object",
"properties": {
"categories": {
"type": "array",
"items": {
"type": "object",
"properties": {
"name": {"type": "string", "description": "The category name."},
"score": {"type": "number", "description": "The classification score for the category, ranging from 0.0 to 1.0."}
},
"required": ["name", "score"]
}
}
},
"required": ["categories"]
}
}
]

text = "The new quantum computing breakthrough could revolutionize the tech industry."

query = f"""
<document>
{text}
</document>

Use the print_classification tool. The categories can be Politics, Sports, Technology, Entertainment, Business.
"""

response = client.messages.create(
model=MODEL_NAME,
max_tokens=4096,
tools=tools,
messages=[{"role": "user", "content": query}]
)

json_classification = None
for content in response.content:
if content.type == "tool_use" and content.name == "print_classification":
json_classification = content.input
break

if json_classification:
print("Text Classification (JSON):")
print(json.dumps(json_classification, indent=2))
else:
print("No text classification found in the response.")
Text Classification (JSON):
{
"categories": [
{
"name": "Politics",
"score": 0.1
},
{
"name": "Sports",
"score": 0.1
},
{
"name": "Technology",
"score": 0.7
},
{
"name": "Entertainment",
"score": 0.1
},
{
"name": "Business",
"score": 0.5
}
]
}
Example 5: Working with unknown keys
In some cases you may not know the exact JSON object shape up front. In this example we provide an open ended input_schema and instruct Claude via prompting how to interact with the tool.

tools = [
{
"name": "print_all_characteristics",
"description": "Prints all characteristics which are provided.",
"input_schema": {
"type": "object",
"additionalProperties": True
}
}
]

query = f"""Given a description of a character, your task is to extract all the characteristics of the character and print them using the print_all_characteristics tool.

The print_all_characteristics tool takes an arbitrary number of inputs where the key is the characteristic name and the value is the characteristic value (age: 28 or eye_color: green).

<description>
The man is tall, with a beard and a scar on his left cheek. He has a deep voice and wears a black leather jacket.
</description>

Now use the print_all_characteristics tool."""

response = client.messages.create(
model=MODEL_NAME,
max_tokens=4096,
tools=tools,
tool_choice={"type": "tool", "name": "print_all_characteristics"},
messages=[{"role": "user", "content": query}]
)

tool_output = None
for content in response.content:
if content.type == "tool_use" and content.name == "print_all_characteristics":
tool_output = content.input
break

if tool_output:
print("Characteristics (JSON):")
print(json.dumps(json_classification, indent=2))
else:
print("Something went wrong.")
Characteristics (JSON):
{
"height": "tall",
"facial_hair": "beard",
"facial_features": "scar on left cheek",
"voice": "deep voice",
"clothing": "black leather jacket"
}
These examples demonstrate how you can use Claude and the tool use feature to extract structured JSON data for various natural language processing tasks. By defining custom tools with specific input schemas, you can guide Claude to generate well-structured JSON output that can be easily parsed and utilized in your applications.

Increase output consistency (JSON mode)
Here’s how to make Claude’s responses more consistent:

​
Specify the desired output format
Precisely define your desired output format using JSON, XML, or custom templates so that Claude understands every output formatting element you require.

Example: Standardizing customer feedback

Role Content
User You’re a Customer Insights AI. Analyze this feedback and output in JSON format with keys: “sentiment” (positive/negative/neutral), “key_issues” (list), and “action_items” (list of dicts with “team” and “task”).

”I’ve been a loyal user for 3 years, but the recent UI update is a disaster. Finding basic features is now a scavenger hunt. Plus, the new ‘premium’ pricing is outrageous. I’m considering switching unless this is fixed ASAP.”
Assistant {
“sentiment”: “negative”,
“key_issues”: [
“Poor UI/UX in recent update”,
“Difficulty finding basic features”,
“Perceived high pricing (new ‘premium’ tier)”
],
“action_items”: [
{
“team”: “Product”,
“task”: “Conduct usability testing and iterate on UI based on findings”
},
{
“team”: “UX”,
“task”: “Create a feature discovery guide or onboarding flow”
},
{
“team”: “Marketing”,
“task”: “Review pricing strategy and communicate value proposition”
},
{
“team”: “Customer Success”,
“task”: “Reach out to user, offer concessions to prevent churn”
}
]
}
​
Prefill Claude’s response
Prefill the Assistant turn with your desired format. This trick bypasses Claude’s friendly preamble and enforces your structure.

Example: Daily sales report

Role Content
User You’re an insightful Sales Intelligence AI. Generate today’s sales report.

Structure the report like this:

<report>
<summary>
<metric name=“total_revenue”>$0.00</metric>
<metric name=“units_sold”>0</metric>
<metric name=“avg_order_value”>$0.00</metric>
</summary>
<top_products>
<product>
<name>Product Name</name>
<revenue>$0.00</revenue>
<units>0</units>
</product>
…
</top_products>
<regional_performance>
<region>
<name>Region Name</name>
<revenue>$0.00</revenue>
<growth>0.0%</growth>
</region>
…
</regional_performance>
<action_items>
<item>Action item.</item>
…
</action_items>
</report>
Assistant (prefill)	<report>
<summary>
<metric name=
Assistant	”total_revenue”>$842,567.00</metric>
<metric name=“units_sold”>15,238</metric>
<metric name=“avg_order_value”>$55.29</metric>
</summary>
<top_products>
<product>
<name>AcmeGuard Pro</name>
<revenue>$325,890.00</revenue>
<units>3,621</units>
</product>
<product>
<name>AcmeVault Enterprise</name>
<revenue>$254,400.00</revenue>
<units>1,272</units>
</product>
<product>
<name>AcmeBoost XL</name>
<revenue>$147,690.00</revenue>
<units>4,923</units>
</product>
</top_products>
<regional_performance>
<region>
<name>APAC</name>
<revenue>$258,960.00</revenue>
<growth>12.8%</growth>
</region>
<region>
<name>EMEA</name>
<revenue>$325,478.00</revenue>
<growth>3.2%</growth>
</region>
<region>
<name>Americas</name>
<revenue>$258,129.00</revenue>
<growth>-2.1%</growth>
</region>
</regional_performance>
<action_items>
<item>Investigate Americas revenue drop; schedule regional sales team meeting.</item>
<item>Accelerate CloudGuard Pro rollout in APAC to capitalize on growth.</item>
<item>Review NetBoost XL pricing; high volume but lower revenue.</item>
</action_items>
</report>
​
Constrain with examples
Provide examples of your desired output. This trains Claude’s understanding better than abstract instructions.

Example: Generating consistent market intelligence

Role Content
User As a Market Intelligence AI, your task is to analyze data about our competitors. Here is our competitor data:
<data>
{{DATA}}
</data>

Output following this example format:

<competitor>
<name>Rival Inc</name>
<overview>A 50-word summary.</overview>
<swot>
<strengths>- Bullet points</strengths>
<weaknesses>- Bullet points</weaknesses>
<opportunities>- Bullet points</opportunities>
<threats>- Bullet points</threats>
</swot>
<strategy>A 30-word strategic response.</strategy>
</competitor>

Now, analyze AcmeGiant and AcmeDataCo using this format.
Assistant <competitor>
<name>AcmeGiant</name>
<overview>Global tech leader with a vast ecosystem of consumer and enterprise products. Known for innovation, strong brand, and deep customer lock-in through integrated hardware, software, and services.</overview>
<swot>
<strengths>

- Massive R&D budget fuels continuous innovation
- Loyal customer base and powerful brand recognition
- Synergistic product ecosystem increases switching costs
  </strengths>
  <weaknesses>
- High prices may deter cost-sensitive customers
- Slow to address enterprise-specific customization needs
- Privacy concerns and regulatory scrutiny in multiple markets
  </weaknesses>
  <opportunities>
- Growing demand for AI and ML capabilities
- Expansion into emerging markets
- Acquisitions to fill product or talent gaps
  </opportunities>
  <threats>
- Rapid rise of cloud-native competitors
- Antitrust lawsuits and regulatory actions
- Talent poaching by startups and competitors
  </threats>
  </swot>
  <strategy>Focus on our agility and customization. Target TechGiant’s slow enterprise response and privacy issues in our marketing.</strategy>
  </competitor>

<competitor>
<name>AcmeDataCo</name>
<overview>Rising star in data analytics and visualization. Offers intuitive, self-service BI tools with a freemium model, appealing to startups and enterprise teams alike.</overview>
<swot>
<strengths>
- User-friendly interface reduces need for specialized training
- Freemium model lowers barrier to entry, drives viral growth
- Strong product-market fit with rise of data-driven decisions
</strengths>
<weaknesses>
- Limited advanced analytics compared to established BI tools
- Scaling issues reported with very large datasets
- Dependent on third-party cloud infrastructure (AWS)
</weaknesses>
<opportunities>
- Expanding into predictive analytics and AI-driven insights
- Forming strategic alliances with complementary tech vendors
- Customizable dashboards for industry-specific solutions
</opportunities>
<threats>
- Market saturation; many new entrants in self-service BI
- Enterprise BI giants developing more user-friendly tools
- Data privacy regulations increasing compliance complexity
</threats>
</swot>
<strategy>Highlight our robust enterprise features and data governance. Target accounts struggling with DataCo’s scale limitations.</strategy>
</competitor>
​
Use retrieval for contextual consistency
For tasks requiring consistent context (e.g., chatbots, knowledge bases), use retrieval to ground Claude’s responses in a fixed information set.

Example: Enhancing IT support consistency

Role Content
User You’re our IT Support AI that draws on knowledge base data. Here are entries from your knowledge base:

<kb>
<entry>
<id>1</id>
<title>Reset Active Directory password</title>
<content>1. Go to password.ourcompany.com
2. Enter your username
3. Click “Forgot Password”
4. Follow email instructions</content>
</entry>
<entry>
<id>2</id>
<title>Connect to VPN</title>
<content>1. Install GlobalProtect from software center
2. Open GlobalProtect, enter “vpn.ourcompany.com”
3. Use AD credentials to log in</content>
</entry>
</kb>

When helping users, always check the knowledge base first. Respond in this format:

<response>
<kb_entry>Knowledge base entry used</kb_entry>
<answer>Your response</answer>
</response> Write some test questions for yourself and answer them using the knowledge base, just to make sure you understand how to use the knowledge base properly.
Assistant	Understood. I’ll use the knowledge base for consistent responses. Let’s test with a couple of scenarios.

User: Hey, I can’t log into my email. I think I forgot my password.

<response>
<kb_entry>1: Reset Active Directory password</entry>
<answer>I understand you’re having trouble logging into your email due to a forgotten password. No worries, this is a common issue. To reset your Active Directory password, which is used for email access, follow these steps:

1. Go to password.ourcompany.com
2. Enter your username (same as your email address)
3. Click on the “Forgot Password” link
4. You’ll receive an email with instructions. Follow them to reset your password.

After resetting, you should be able to log into your email. Let me know if you need any further assistance.</answer>
</response>

User: I’m working from home today. How do I access internal resources?

<response>
<kb_entry>2: Connect to VPN</entry>
<answer>Great question! To access internal resources while working from home, you’ll need to connect to our company VPN (Virtual Private Network). Here’s how to set that up:

1. First, install the GlobalProtect VPN client. You can find this in our software center.
2. Once installed, open the GlobalProtect application.
3. In the server field, enter “vpn.ourcompany.com”.
4. Use your Active Directory (AD) credentials to log in - the same username and password you use for your email.

Once connected, you’ll have secure access to all internal resources as if you were in the office. Let me know if you run into any issues during setup.</answer>
</response>
​
Chain prompts for complex tasks
Break down complex tasks into smaller, consistent subtasks. Each subtask gets Claude’s full attention, reducing inconsistency errors across scaled workflows.

arge Language Models (LLMs) are revolutionizing how we interact with data, but getting these models to generate well-formatted & usable JSON responses consistently can feel like herding digital cats. You ask for structured data and get a jumbled mess interspersed with friendly commentary. Frustrating, right?

A reliable JSON output is crucial, whether you’re categorizing customer feedback, extracting structured data from unstructured text, or automating data pipelines. This article aims to provide a comprehensive, generalized approach to ensure you get perfectly formatted JSON from any LLM, every time.

The Problem

Imagined with Meta AI
LLMs are trained on massive text datasets, making them adept at generating human-like text. However, this strength becomes a weakness when seeking precise, structured output like JSON or Python Dictionary.

Common issues include:

Inconsistent Formatting: Random spaces, line breaks, and inconsistent quoting can break JSON parsers.
Extraneous Text: LLMs often add conversational fluff before or after the JSON, making extraction difficult.
Hallucinations: LLMs might invent data points or misinterpret instructions, leading to invalid or inaccurate JSON.
These issues can disrupt downstream processes and lead to significant inefficiencies. Let’s explore some proven techniques to overcome these challenges.

The Solution: A Multi-Layered Approach

Generated by DALL.E 3

1. Guiding the LLM with Clear Instructions
   Explicitly Request JSON: Clearly state that you expect the output in JSON format. Explicitly stating the intended use of the JSON output in the prompt can significantly improve its validity. Giving explicit instructions to provide a structured response in “system_prompt” can also prove helpful.
   json_prompt = """Ensure the output is valid JSON as it will be parsed
   using `json.loads()` in Python.
   It should be in the schema:
   <output>
   {
   "cars": [
   {
   "model": "<model_name1>",
   "color": "<color1>"
   },
   {
   "model": "<model_name2>",
   "color": "<color2>"
   },
   {
   "model": "<model_name3>",
   "color": "<color3>"
   },
   {
   "model": "<model_name4>",
   "color": "<color4>"
   },
   {
   "model": "<model_name5>",
   "color": "<color5>"
   }
   ]
   }
   </output>
   """
   #Defining system prompt
   system_prompt = "You are an AI language model that provides structured JSON outputs."
   Provide a JSON Schema: Define the exact structure of the desired JSON, including keys and data types.
   Use Examples: Show the LLM examples of correctly formatted JSON output for your specific use case.
   As suggested in Anthropic Documentation, one more effective method is to guide the LLM by pre-filling the assistant’s response with the beginning of the JSON structure. This technique leverages the model’s ability to continue from a given starting point.

Example:

import boto3
import json
from botocore.exceptions import ClientError
from dotenv import load_dotenv
import os

load_dotenv()

# AWS Bedrock setup

session = boto3.Session(
region_name=os.getenv("AWS_DEFAULT_REGION"),
aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID"),
aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY"),
)

bedrock = session.client(service_name="bedrock-runtime")

# Create a Bedrock Runtime client in the AWS Region of your choice.

client = boto3.client("bedrock-runtime", region_name="us-east-1")

# Set the model ID for Claude.

model_id = "anthropic.claude-3-haiku-20240307-v1:0"

# Define the JSON schema and example prefill response with stop sequences.

output_start = """<output>\n{\n"cars":"""
closing_bracket = "]\n}\n</output>"
json_prompt = """Ensure the output is valid JSON as it will be parsed
using `json.loads()` in Python.
It should be in the schema:
<output>
{
"cars": [
{
"model": "<model_name1>",
"color": "<color1>"
},
{
"model": "<model_name2>",
"color": "<color2>"
},
{
"model": "<model_name3>",
"color": "<color3>"
},
{
"model": "<model_name4>",
"color": "<color4>"
},
{
"model": "<model_name5>",
"color": "<color5>"
}
]
}
</output>
"""

# Define the prompt for the model.

prompt = f"""Provide an example of 5 cars with their color and models in JSON format enclosed in <output></output> XML tags.
{json_prompt}"""

# Prefilled part of the response.

prefilled_response = output_start

# Define the system prompt.

system_prompt = "You are an AI language model that provides structured JSON outputs."

# Format the request payload using the model's native structure.

native_request = {
"anthropic_version": "bedrock-2023-05-31",
"max_tokens": 1024,
"temperature": 0.01,
"stop_sequences": ["\n\nHuman:", closing_bracket],
"system": f"<system>{system_prompt}</system>",
"messages": [
{
"role": "user",
"content": [{"type": "text", "text": prompt}],
},
{
"role": "assistant",
"content": [{"type": "text", "text": prefilled_response}]
}
],
}

# Convert the native request to JSON.

request = json.dumps(native_request)

try: # Invoke the model with the request.
response = client.invoke_model(modelId=model_id, body=request)

    # Decode the response body.
    model_response = json.loads(response["body"].read())

    # Extract and print the response text.
    completion = model_response["content"][0]["text"]
    final_result = prefilled_response + completion + closing_bracket

    print(final_result)

except (ClientError, Exception) as e:
print(f"ERROR: Can't invoke '{model_id}'. Reason: {e}")
exit(1)
Output :

<output>
{
"cars":
[
    {
    "model": "Toyota Corolla",
    "color": "Silver"
    },
    {
    "model": "Honda Civic",
    "color": "Blue"
    },
    {
    "model": "Ford Mustang",
    "color": "Red"
    },
    {
    "model": "Chevrolet Camaro",
    "color": "Black"
    },
    {
    "model": "Nissan Altima",
    "color": "White"
    }
]
}
</output>
The salient features of this method are :

Prefilling the Response: “Put words in the LLM’s mouth” by starting the assistant’s response with the opening bracket `{` or other relevant beginning sequences as we have used above <output>\n{\n"cars":. This encourages the model to follow the expected format.
Strategic Stop Sequences: Define stop sequences ( like `}` or specific keywords, for example : ]\n}\n</output>. ) to prevent the LLM from adding extraneous text after the JSON.
Leveraging Tags for Complex Outputs: For multiple JSON objects, ask the output to be enclosed within unique tags ( e.g., <output>...</output> XML tags ). This allows for easy extraction using regular expressions.
Extracting the JSON response between XML tags :
When working with APIs or systems that return responses wrapped in XML tags, it becomes crucial to extract and utilize the JSON data embedded within those tags. Below, we’ll explore methods to extract JSON data from XML tags both with and without the use of regular expressions (regex), followed by saving the extracted data to a JSON file.

Using Regular Expressions (Regex)
Regex can be a powerful tool for pattern matching and extraction. In this case, we can use regex to locate the JSON content within the specified XML tags.

import json
import re

def extract_json_with_regex(response: str):
pattern = r"<output>(.\*?)</output>" # Search for the pattern <output>...</output>
match = re.search(pattern, response, re.DOTALL)

    if match:
        # Extract the content between the tags
        json_str = match.group(1).strip()
        try:
            # Parse the string to a JSON object
            json_data = json.loads(json_str)
            return json_data
        except json.JSONDecodeError:
            # Return None if JSON parsing fails
            return None
    # Return None if no match is found
    return None

In this function, re.search() is used to find the first occurrence of the pattern <output>...</output> in the response. If found, it extracts the content between these tags and attempts to parse it as JSON. If parsing fails, it returns None.

Without Using Regular Expressions
For scenarios where you prefer not to use regex, a more manual approach can be employed to achieve the same goal.

import json

def extract_json_without_regex(response: str):
start_tag = "<output>"
end_tag = "</output>" # Find the start and end indices of the tags
start_index = response.find(start_tag)
end_index = response.find(end_tag)

    if start_index != -1 and end_index != -1:
        # Adjust start index to get the content after the start tag
        start_index += len(start_tag)
        # Extract the content between the tags
        json_str = response[start_index:end_index].strip()
        try:
            # Parse the string to a JSON object
            json_data = json.loads(json_str)
            return json_data
        except json.JSONDecodeError:
            # Return None if JSON parsing fails
            return None
    # Return None if tags are not found
    return None

This function locates the starting and ending positions of the <output> and </output> tags manually, extracts the content between them and attempts to parse it as JSON. Like the regex approach, it returns None if parsing fails or the tags are not found.

Saving Extracted JSON to a File
After extracting the JSON data, the next step is to save it to a file for further processing or record-keeping. The function below handles this task.

def save_json_to_file(json_data, file_name='output.json'):
with open(file_name, 'w') as json_file: # Save the JSON data to the specified file with indentation for readability
json.dump(json_data, json_file, indent=4)
print(f"JSON data saved to {json_file.name}")
This utility function opens a file in write mode and uses json.dump() to write the JSON data to it, ensuring the output is formatted with an indentation of 4 spaces for better readability.

Final JSON result (output.json):

{
"cars": [
{
"model": "Toyota Corolla",
"color": "Silver"
},
{
"model": "Honda Civic",
"color": "Blue"
},
{
"model": "Ford Mustang",
"color": "Red"
},
{
"model": "Chevrolet Camaro",
"color": "Black"
},
{
"model": "Nissan Altima",
"color": "White"
}
]
} 2. Validating and Repairing JSON Response
Despite employing the earlier techniques, minor syntax errors can occasionally disrupt the JSON structure. These errors can be addressed using the following methods:

We can fix these minor errors using some simple methods :

Requesting the LLM to Correct the JSON: Feed the malformed JSON back to the LLM and prompt it to correct the errors.
Utilizing JSON Repair Tools: Using tools like `json_repair` or `half-json` can help correct these errors quickly.
The second method is generally more economical, faster, and reliable for straightforward cleanup tasks. In contrast, the first method may be more effective for addressing complex issues, albeit at the cost of additional time and an extra LLM call.

Example (using json-repair):

pip install json-repair
from json_repair import repair_json

cleaned_final_result = repair_json(final_result)

#You can also use this library to completely replace json.loads():

import json_repair

decoded_object = json_repair.loads(json_string)
Example (Asking LLM to fix broken JSON) :

import boto3
import json
from botocore.exceptions import ClientError
from dotenv import load_dotenv
import os

# Load environment variables from a .env file

load_dotenv()

# AWS Bedrock setup with credentials and region from environment variables

session = boto3.Session(
region_name=os.getenv("AWS_DEFAULT_REGION"),
aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID"),
aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY"),
)

# Create a Bedrock Runtime client using the session

bedrock = session.client(service_name="bedrock-runtime")

# Create a Bedrock Runtime client in the AWS Region of your choice (hardcoded to 'us-east-1')

client = boto3.client("bedrock-runtime", region_name="us-east-1")

# Set the model ID for Claude

model_id = "anthropic.claude-3-haiku-20240307-v1:0"

# Define the prefill response with stop sequences.

output_start = "{"
closing_bracket = "\n}"

#Example of Broken/Invalid JSON
json_prompt =
"""
{
"cars": [
{
"model": Toyota Corolla, # Missing quotes around the value
"color": "Silver"
},
{
"model": "Honda Civic",
"color": "Blue # Missing closing quote
},
{
"model": "Ford Mustang",
"color": "Red"
},
{
model: Chevrolet Camaro, # Missing quotes around the key and value
"color": 'Black" # Mixed quotes, opening with ' and closing with "
, # Missing closing brace for the object
{
"model": "Nissan Altima",
"color": "White # Missing closing quote and closing brace for the object
}
]  
}  
"""

# Define the prompt for the model

prompt = f"""Fix the JSON below:\n{json_prompt}"""

# Prefilled part of the response

prefilled_response = output_start

# Generic System prompt for JSON Repairing via LLM.

system_prompt = """

### Instruction

Your task is to act as an expert JSON fixer and repairer. You are responsible for correcting any broken JSON and ensuring there are no syntax errors. The resulting JSON should be validated and easily parsed using `json.loads()` in Python.

### Context

JSON is built on two primary structures:

1. A collection of name/value pairs, realized in various languages as an object, record, struct, dictionary, hash table, keyed list, or associative array.
2. An ordered list of values, realized in most languages as an array, vector, list, or sequence.

These structures are supported by virtually all modern programming languages, making JSON a widely used data interchange format.

In JSON, the structures take the following forms:

- An **object** is an unordered set of name/value pairs. An object begins with a `{` (left brace) and ends with a `}` (right brace). Each name is followed by a `:` (colon) and the name/value pairs are separated by `,` (comma).
- An **array** is an ordered collection of values. An array begins with a `[` (left bracket) and ends with a `]` (right bracket). Values are separated by `,` (comma).

### Requirements

1. Repair only the JSON structure without changing or modifying any data or values of the keys.
2. Ensure that the data is accurately represented and properly formatted within the JSON structure.
3. The resulting JSON should be validated and able to be parsed using `json.loads()` in Python.

### Example

#### Broken JSON

{
"name": "John Doe",
"age": 30,
"isStudent": false
"courses": ["Math", "Science"]
"address": {
"street": "123 Main St",
"city": "Anytown",
"zipcode": "12345"
}

#### Fixed JSON

{
"name": "John Doe",
"age": 30,
"isStudent": false,
"courses": ["Math", "Science"],
"address": {
"street": "123 Main St",
"city": "Anytown",
"zipcode": "12345"
}
}

### Notes

- Pay close attention to missing commas, unmatched braces or brackets, and any other structural issues.
- Maintain the integrity of the data without making assumptions or altering the content.
- Ensure the output is clean, precise, and ready for parsing in Python.
  """

# Format the request payload using the model's native structure

native_request = {
"anthropic_version": "bedrock-2023-05-31",
"max_tokens": 1024,
"temperature": 0.01,
"stop_sequences": ["\n\nHuman:", closing_bracket],
"system": f"<system>{system_prompt}</system>",
"messages": [
{
"role": "user",
"content": [{"type": "text", "text": prompt}],
},
{
"role": "assistant",
"content": [{"type": "text", "text": prefilled_response}]
}
],
}

# Convert the native request to JSON

request = json.dumps(native_request)

try: # Invoke the model with the request
response = client.invoke_model(modelId=model_id, body=request)

    # Decode the response body
    model_response = json.loads(response["body"].read())

    # Extract and print the response text
    completion = model_response["content"][0]["text"]
    final_result = prefilled_response + completion + closing_bracket

    print(final_result)

except (ClientError, Exception) as e:
print(f"ERROR: Can't invoke '{model_id}'. Reason: {e}")
exit(1)
Output (as JSON) :

{
"cars": [
{
"model": "Toyota Corolla",
"color": "Silver"
},
{
"model": "Honda Civic",
"color": "Blue"
},
{
"model": "Ford Mustang",
"color": "Red"
},
{
"model": "Chevrolet Camaro",
"color": "Black"
},
{
"model": "Nissan Altima",
"color": "White"
}
]
}
Balanced Perspective
While these techniques can significantly improve the consistency of JSON output from LLMs, they are not foolproof. Potential challenges include:

Increased complexity in prompt design
Additional computational overhead for post-processing
Dependency on external libraries for validation
Moreover, ethical considerations such as data privacy and model biases should always be taken into account when deploying LLMs in production environments.

Actionable Insights

1. Start with a Clear JSON Template: Define the JSON structure and use it as a guide for the LLM with few-shot prompting examples.
2. Leverage Post-Processing Tools: Use tools like `json_repair` to correct minor syntax errors in the JSON output.
3. Iterate and Improve: Continuously refining our prompts and validation rules based on the output and feedback.

By following these steps, we can ensure that our LLM consistently generates well-formatted JSON, making our AI-driven applications more reliable and efficient.

Imagined with Meta AI and Adobe Firefly
Conclusion
Generating perfectly formatted JSON from LLMs is a common yet challenging task. By guiding the JSON syntax, communicating its usage, and using validation tools like json-fixer, we can significantly improve the consistency and reliability of the output. By combining clear instructions, strategic prompting, and robust validation, we can transform our LLM interactions from a gamble into a reliable pipeline for structured data.

That’s all for the day folks, Stay informed, iterate, and refine your approach to master the art of JSON generation from any LLM.

Structured Outputs and Prompt Caching with Anthropic¶
Anthropic's ecosystem now offers two powerful features for AI developers: structured outputs and prompt caching. These advancements enable more efficient use of large language models (LLMs). This guide demonstrates how to leverage these features with the Instructor library to enhance your AI applications.

Structured Outputs with Anthropic and Instructor¶
Instructor now offers seamless integration with Anthropic's powerful language models, allowing developers to easily create structured outputs using Pydantic models. This integration simplifies the process of extracting specific information from AI-generated responses.

To get started, you'll need to install Instructor with Anthropic support:

pip install instructor[anthropic]
Here's a basic example of how to use Instructor with Anthropic:

from pydantic import BaseModel
from typing import List
import anthropic
import instructor

# Patch the Anthropic client with Instructor

anthropic_client = instructor.from_anthropic(create=anthropic.Anthropic())

# Define your Pydantic models

class Properties(BaseModel):
name: str
value: str

class User(BaseModel):
name: str
age: int
properties: List[Properties]

# Use the patched client to generate structured output

user_response = anthropic_client(
model="claude-3-haiku-20240307",
max_tokens=1024,
messages=[
{
"role": "user",
"content": "Create a user for a model with a name, age, and properties.",
}
],
response_model=User,
)

print(user_response.model_dump_json(indent=2))
"""
{
"name": "John Doe",
"age": 30,
"properties": [
{ "name": "favorite_color", "value": "blue" }
]
}
"""
This approach allows you to easily extract structured data from Claude's responses, making it simpler to integrate AI-generated content into your applications.

Prompt Caching: Boosting Performance and Reducing Costs¶
Anthropic has introduced a new prompt caching feature that can significantly improve response times and reduce costs for applications dealing with large context windows. This feature is particularly useful when making multiple calls with similar large contexts over time.

Here's how you can implement prompt caching with Instructor and Anthropic:

from anthropic import Anthropic
from pydantic import BaseModel

# Set up the client with prompt caching

client = instructor.from_anthropic(Anthropic())

# Define your Pydantic model

class Character(BaseModel):
name: str
description: str

# Load your large context

with open("./book.txt") as f:
book = f.read()

# Make multiple calls using the cached context

for \_ in range(2):
resp, completion = client.chat.completions.create_with_completion(
model="claude-3-haiku-20240307",
messages=[
{
"role": "user",
"content": [
{
"type": "text",
"text": "<book>" + book + "</book>",
"cache_control": {"type": "ephemeral"},
},
{
"type": "text",
"text": "Extract a character from the text given above",
},
],
},
],
response_model=Character,
max_tokens=1000,
)
In this example, the large context (the book content) is cached after the first request and reused in subsequent requests. This can lead to significant time and cost savings, especially when working with extensive context windows.

Conclusion¶
By combining Anthropic's Claude with Instructor's structured output capabilities and leveraging prompt caching, developers can create more efficient, cost-effective, and powerful AI applications. These features open up new possibilities for building sophisticated AI systems that can handle complex tasks with ease.

As the AI landscape continues to evolve, staying up-to-date with the latest tools and techniques is crucial. We encourage you to explore these features and share your experiences with the community. Happy coding!
