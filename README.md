# Document knowledge mining solution accelerator

Ingest, extract, and classify content from a high volume of assets to gain deeper insights and generate relevant suggestions for quick and easy reasoning. This enables the ability to conduct chat-based insight discovery, analysis, and receive suggested prompt guidance to further explore your data.

<br/>

<div align="center">
  
[**SOLUTION OVERVIEW**](#solution-overview)  \| [**QUICK DEPLOY**](#quick-deploy)  \| [**BUSINESS USE CASE**](#business-use-case)  \| [**SUPPORTING DOCUMENTATION**](#supporting-documentation)

</div>
<br/>

<h2><img src="./docs/images/readme/solution-overview.png" width="48" />
Solution overview
</h2>

This solution leverages Azure OpenAI and Azure AI Document Intelligence in a hybrid approach by combining Optical Character Recognition (OCR) and multi-modal Large Language Model (LLM) to extract information from documents to provide insights without pre-training including text documents, handwritten text, charts, graphs, tables, and form fields.

### Solution architecture
|![image](./docs/images/readme/solution-architecture.png)|
|---|

### How to customize
If you'd like to customize the solution accelerator, here are some common areas to start:

[Technical architecture](./docs/TechnicalArchitecture.md)

[Content and data processing workflow](./docs/DataProcessing.md)

<br/>


### Key features
<details open>
  <summary>Click to learn more about the key features this solution enables</summary>

  - **Ingest and extract real-world entities** <br/>
  Process and extract information unique to your ingested data pipeline such as people, products, events, places, or behaviors. Used to populate filters.
  
  - **Chat-based insights discovery** <br/>
  Choose to chat with all indexed assets, a single asset, select a set of assets, or chat with a generated list of assets from a based on a user-led keyword search.

  - **Text and document data analysis** <br/>
  Analyze, compare, and synthesize materials into deep insights, making content accessible through natural language prompting.

  - **Prompt ​suggestion ​guidance** <br/>
  Suggest a next best set of questions based on the prompt inquiry. Include referenced materials to guide deeper avenues of user-led discovery.​

  - **​Multi-modal information processing** <br/>
  Ingest and extract knowledge from multiple content types and various format types. Enhance with scanned images, handwritten forms, and text-based tables.​

</details>



<br /><br />
<h2><img src="./docs/images/readme/quick-deploy.png" width="48" />
Quick deploy
</h2>

### How to install or deploy
Follow the quick deploy steps on the deployment guide to deploy this solution to your own Azure subscription.

> **Note:** This solution accelerator requires **Azure Developer CLI (azd) version 1.18.0 or higher**. Please ensure you have the latest version installed before proceeding with deployment. [Download azd here](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd).

[Click here to launch the deployment guide](./docs/DeploymentGuide.md)
<br/><br/>



> ⚠️ **Important: Check Azure OpenAI Quota Availability**
 <br/>To ensure sufficient quota is available in your subscription, please follow [quota check instructions guide](./docs/QuotaCheck.md) before you deploy the solution.

<br/>

### Prerequisites and costs

To deploy this solution accelerator, ensure you have access to an [Azure subscription](https://azure.microsoft.com/free/) with the necessary permissions to create **resource groups, resources, app registrations, and assign roles at the resource group level**. This should include Contributor role at the subscription level and  Role Based Access Control role on the subscription and/or resource group level. Follow the steps in [Azure Account Set Up](./docs/AzureAccountSetUp.md).

*Note: Due to model availability within various data center regions, the following services have been hard-coded to specific regions:*

* **Azure Open AI (GPT 4o mini):**<br>
The solution relies on `GPT-4o mini` and `text-embedding-3-large` models which are all currently available in the 'WestUS3', 'EastUS', 'EastUS2', 'SwedenCentral' region.  
Please check the
[model summary table and region availability](https://learn.microsoft.com/en-us/azure/ai-services/openai/concepts/models#embeddings) if needed.

* **Azure AI Document Intelligence (East US):**<br>
The solution relies on a `2023-10-31-preview` or later that is currently available in `East US` region.  
The deployment region for this model is fixed in 'East US'

Check the [Azure Products by Region](https://azure.microsoft.com/en-us/explore/global-infrastructure/products-by-region/?products=all&regions=all) page and select a **region** where the following services are available.

Pricing varies per region and usage, so it isn't possible to predict exact costs for your usage. The majority of the Azure resources used in this infrastructure are on usage-based pricing tiers. However, Azure Container Registry has a fixed cost per registry per day.

Use the [Azure pricing calculator](https://azure.microsoft.com/en-us/pricing/calculator) to calculate the cost of this solution in your subscription. 

Review a [sample pricing sheet](https://azure.com/e/94cf771516ec4812b36c5f2e3e6b4121) in the event you want to customize and scale usage.

_Note: This is not meant to outline all costs as selected SKUs, scaled use, customizations, and integrations into your own tenant can affect the total consumption of this sample solution. The sample pricing sheet is meant to give you a starting point to customize the estimate for your specific needs._

<br/>


| Product | Description | Cost |
|---|---|---|
| [Azure OpenAI Service](https://learn.microsoft.com/en-us/azure/ai-services/openai/) | Used for chat exerpeince/RAG in wen app, data processing workflow for extraction and summarization. | [Pricing](https://azure.microsoft.com/en-us/pricing/details/cognitive-services/openai-service/) |
| [Azure AI Search](https://learn.microsoft.com/en-us/azure/search/) | Processed and extracted document information is added to an Azure AI Search vecortized index. | [Pricing](https://learn.microsoft.com/en-us/azure/search/) |
| [Azure AI Document Intelligence](https://learn.microsoft.com/en-us/azure/ai-services/document-intelligence/)| Used during data processing workflow where documents have Optical Character Recognition (OCR) applied to extract data. | [Pricing](https://azure.microsoft.com/en-us/pricing/details/ai-document-intelligence/) |
| [Azure Container Registry](https://learn.microsoft.com/en-us/azure/container-registry/)| Private registry where the Document Processor, AI Service, and Web App images are built, stored and managed. | [Pricing](https://azure.microsoft.com/pricing/details/container-registry/) |
| [Azure Kubernetes Service (AKS)](https://learn.microsoft.com/azure/aks/)| The solution is deployed as a managed container app with with high availability, scalability, and region portability. | [Pricing](https://azure.microsoft.com/en-us/pricing/details/kubernetes-service/) |
| [Azure App Service](https://learn.microsoft.com/en-us/azure/app-service/)| UI web application for the solution built with React and TypeScript. | [Pricing]() |
| [Azure Blob Storage](https://learn.microsoft.com/en-us/azure/storage/blobs/)| Storage of document files that are being proessed. | [Pricing](https://azure.microsoft.com/pricing/details/storage/blobs/) |
| [Azure Queue Storage](https://learn.microsoft.com/en-us/azure/storage/queues/)| Pipeline workflow steps and processing job management. | [Pricing](https://github.com/microsoft/content-processing-solution-accelerator/blob/main) |
| [Azure Cosmos DB](https://learn.microsoft.com/en-us/azure/cosmos-db/)| Processed document results and chat history storage. | [Pricing](https://azure.microsoft.com/en-us/pricing/details/cosmos-db/autoscale-provisioned/) |

<br/>

>⚠️ **Important:** To avoid unnecessary costs, remember to take down your app if it's no longer in use,
either by deleting the resource group in the Portal or running `azd down`.

<br /><br />
<h2><img src="./docs/images/readme/business-scenario.png" width="48" />
Business use case
</h2>


|![image](./docs/images/readme/ui.png)|
|---|

<br/>

In large, enterprise organizations it's difficult and time consuming to analyze large volumes of data. Imagine a mortgage lender working with both residential and commercial clients and she facilitates financing for buyers and sellers by negotiating loan terms, processing mortgage applications, and ensures compliance with federal regulations.

Her challenges include:

* Analyzing large volumes of data in a timely manner, limiting quick decision-making.​
* Inability to compare and synthesize documents limits the contextual relevance of insights.​
* Inability to extract information from charts and tables leads to incomplete analysis and poor decision-making.

The goal of this solution accelerator is to:
* Automate document ingestion to avoid missing critical terms and ensure accuracy.​
* Leverage extracted data to make better-informed loan decisions.​
* Accelerate loan approvals while reducing manual effort.

⚠️ The sample data used in this repository is synthetic and generated using Azure OpenAI service. The data is intended for use as sample data only.


### Business value
<details>
  <summary>Click to learn more about what value this solution provides</summary>

  - **Automate content processing** <br/>
  Process and extract essential details unique to your ingested data pipeline such as people, products, events, places, or behaviors to quickly streamline document review and analysis.

  - **Enhance insight discovery** <br/>
  User-led insight discovery is enabled through indexed, single, and multi-asset selection, including user generated asset lists used to contextualize, compare and synthesize materials into deep insights.

  - **Increase user productivity** <br/>
  Improve productivity with natural language prompting and next best query suggestion, including reference materials and automated filter generation, to guide deeper avenues of user-lead discovery.

  - **Surface multi-modal insights** <br/>
  Data ingested from multiple content types, such as images, handwritten forms, and text-based tables, is extracted and analyzed to surface key insights in conversational context

     
</details>

<br /><br />

<h2><img src="./docs/images/readme/supporting-documentation.png" width="48" />
Supporting documentation
</h2>

### Security guidelines

This template uses Azure Key Vault to store all connections to communicate between resources.

This template also uses [Managed Identity](https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/overview) for local development and deployment.

To ensure continued best practices in your own repository, we recommend that anyone creating solutions based on our templates ensure that the [Github secret scanning](https://docs.github.com/code-security/secret-scanning/about-secret-scanning) setting is enabled.

You may want to consider additional security measures, such as:

* Enabling Microsoft Defender for Cloud to [secure your Azure resources](https://learn.microsoft.com/en-us/azure/defender-for-cloud/).
* Protecting the Azure Container Apps instance with a [firewall](https://learn.microsoft.com/azure/container-apps/waf-app-gateway) and/or [Virtual Network](https://learn.microsoft.com/azure/container-apps/networking?tabs=workload-profiles-env%2Cazure-cli).

<br/>

### Cross references
Check out similar solution accelerators

| Solution Accelerator | Description |
|---|---|
| [Conversation&nbsp;knowledge&nbsp;mining](https://github.com/microsoft/Conversation-Knowledge-Mining-Solution-Accelerator) | Derive insights from volumes of conversational data using generative AI. It offers key phrase extraction, topic modeling, and interactive chat experiences through an intuitive web interface. |
| [Content&nbsp;processing](https://github.com/microsoft/content-processing-solution-accelerator) | Programmatically extract data and apply schemas to unstructured documents across text-based and multi-modal content using Azure AI Foundry, Azure OpenAI, Azure AI Content Understanding, and Azure Cosmos DB. |
| [Build&nbsp;your&nbsp;own&nbsp;copilot&nbsp;-&nbsp;client&nbsp;advisor](https://github.com/microsoft/build-your-own-copilot-solution-accelerator) | This copilot helps client advisors to save time and prepare relevant discussion topics for scheduled meetings. It provides an overview of daily client meetings with seamless navigation between viewing client profiles and chatting with structured data. |


<br/>   


## Provide feedback

Have questions, find a bug, or want to request a feature? [Submit a new issue](https://github.com/microsoft/document-knowledge-mining-solution-accelerator/issues) on this repo and we'll connect.

<br/>

## Responsible AI Transparency FAQ 
Please refer to [Transparency FAQ](./TRANSPARENCY_FAQ.md) for responsible AI transparency details of this solution accelerator.

<br/>

## Disclaimers

This release is an artificial intelligence (AI) system that generates text based on user input. The text generated by this system may include ungrounded content, meaning that it is not verified by any reliable source or based on any factual data. The data included in this release is synthetic, meaning that it is artificially created by the system and may contain factual errors or inconsistencies. Users of this release are responsible for determining the accuracy, validity, and suitability of any content generated by the system for their intended purposes. Users should not rely on the system output as a source of truth or as a substitute for human judgment or expertise. 

This release only supports English language input and output. Users should not attempt to use the system with any other language or format. The system output may not be compatible with any translation tools or services, and may lose its meaning or coherence if translated. 

This release does not reflect the opinions, views, or values of Microsoft Corporation or any of its affiliates, subsidiaries, or partners. The system output is solely based on the system's own logic and algorithms, and does not represent any endorsement, recommendation, or advice from Microsoft or any other entity. Microsoft disclaims any liability or responsibility for any damages, losses, or harms arising from the use of this release or its output by any user or third party. 

This release does not provide any financial advice, and is not designed to replace the role of qualified wealth advisors in appropriately advising clients. Users should not use the system output for any financial decisions or transactions, and should consult with a professional financial advisor before taking any action based on the system output. Microsoft is not a financial institution or a fiduciary, and does not offer any financial products or services through this release or its output. 

This release is intended as a proof of concept only, and is not a finished or polished product. It is not intended for commercial use or distribution, and is subject to change or discontinuation without notice. Any planned deployment of this release or its output should include comprehensive testing and evaluation to ensure it is fit for purpose and meets the user's requirements and expectations. Microsoft does not guarantee the quality, performance, reliability, or availability of this release or its output, and does not provide any warranty or support for it. 

This Software requires the use of third-party components which are governed by separate proprietary or open-source licenses as identified below, and you must comply with the terms of each applicable license in order to use the Software. You acknowledge and agree that this license does not grant you a license or other right to use any such third-party proprietary or open-source components.  

To the extent that the Software includes components or code used in or derived from Microsoft products or services, including without limitation Microsoft Azure Services (collectively, “Microsoft Products and Services”), you must also comply with the Product Terms applicable to such Microsoft Products and Services. You acknowledge and agree that the license governing the Software does not grant you a license or other right to use Microsoft Products and Services. Nothing in the license or this ReadMe file will serve to supersede, amend, terminate or modify any terms in the Product Terms for any Microsoft Products and Services. 

You must also comply with all domestic and international export laws and regulations that apply to the Software, which include restrictions on destinations, end users, and end use. For further information on export restrictions, visit https://aka.ms/exporting. 

You acknowledge that the Software and Microsoft Products and Services (1) are not designed, intended or made available as a medical device(s), and (2) are not designed or intended to be a substitute for professional medical advice, diagnosis, treatment, or judgment and should not be used to replace or as a substitute for professional medical advice, diagnosis, treatment, or judgment. Customer is solely responsible for displaying and/or obtaining appropriate consents, warnings, disclaimers, and acknowledgements to end users of Customer’s implementation of the Online Services. 

You acknowledge the Software is not subject to SOC 1 and SOC 2 compliance audits. No Microsoft technology, nor any of its component technologies, including the Software, is intended or made available as a substitute for the professional advice, opinion, or judgement of a certified financial services professional. Do not use the Software to replace, substitute, or provide professional financial advice or judgment.  

BY ACCESSING OR USING THE SOFTWARE, YOU ACKNOWLEDGE THAT THE SOFTWARE IS NOT DESIGNED OR INTENDED TO SUPPORT ANY USE IN WHICH A SERVICE INTERRUPTION, DEFECT, ERROR, OR OTHER FAILURE OF THE SOFTWARE COULD RESULT IN THE DEATH OR SERIOUS BODILY INJURY OF ANY PERSON OR IN PHYSICAL OR ENVIRONMENTAL DAMAGE (COLLECTIVELY, “HIGH-RISK USE”), AND THAT YOU WILL ENSURE THAT, IN THE EVENT OF ANY INTERRUPTION, DEFECT, ERROR, OR OTHER FAILURE OF THE SOFTWARE, THE SAFETY OF PEOPLE, PROPERTY, AND THE ENVIRONMENT ARE NOT REDUCED BELOW A LEVEL THAT IS REASONABLY, APPROPRIATE, AND LEGAL, WHETHER IN GENERAL OR IN A SPECIFIC INDUSTRY. BY ACCESSING THE SOFTWARE, YOU FURTHER ACKNOWLEDGE THAT YOUR HIGH-RISK USE OF THE SOFTWARE IS AT YOUR OWN RISK.  
