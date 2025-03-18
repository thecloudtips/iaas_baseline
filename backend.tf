terraform {
  cloud {

    organization = "thecloudtips"

    workspaces {
      name = "use_azure_ai"
    }
  }
}
