import os

import openai
openai.api_type="azure"
openai.api_key="xxx"
openai.api_base="https://nillsf-openai.openai.azure.com/"
openai.api_version = "2023-05-15"

from langchain.embeddings import OpenAIEmbeddings
# Create an instance of the OpenAIEmbeddings class using Azure OpenAI
embeddings = OpenAIEmbeddings(
    deployment="nillsf-embeddings",
    chunk_size=1)

# Testing embeddings
text = "This is how you configure it using openai package."

# Embed a single document
e = embeddings.embed_query(text)

print(len(e)) # should be 1536