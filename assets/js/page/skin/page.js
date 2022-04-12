const skinsPerPage = 60;

export const pages = [
  {
    url: "/recent/bedrock",
    title: "Bedrock most recent",
    description: "Most recently uploaded skins",
    fetchUrl: API_BASE_URL + "/skin/recent_uploads",
    skinsPerPage
  },
  {
    url: "/popular/bedrock",
    title: "Bedrock most used",
    description: "Most used Bedrock skins",
    fetchUrl: API_BASE_URL + "/skin/popular/bedrock",
    skinsPerPage
  },
  {
    url: "/recent/java",
    title: "Java most recent",
    description: "Most recently added Java skins",
    fetchUrl: API_BASE_URL + "/skin/recent/java",
    skinsPerPage
  },
  {
    url: "/popular/java",
    title: "Java most used",
    description: "Most used Java skins",
    fetchUrl: API_BASE_URL + "/skin/popular/java",
    skinsPerPage
  }
]

export const menuPages = [
  ...pages,
  {
    url: "/lookup",
    title: "Lookup profile"
  }
]

export function getPageByPath(path) {
  return pages.find(entry => entry.url === path)
}