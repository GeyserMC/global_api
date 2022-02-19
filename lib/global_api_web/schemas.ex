defmodule GlobalApiWeb.Schemas do
  alias OpenApiSpex.{Reference, Schema}

  defmodule Error do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      description: "Generic format for pretty much every error",
      type: :object,
      properties: %{
        message: %Schema{type: :string, description: "The error message", required: true}
      }
    })
  end

  defmodule ConvertedSkin do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      description: "Data representing a skin that has been converted and uploaded to Java Edition",
      type: :object,
      properties: %{
        hash: %Schema{type: :string, description: "The hash of the skin bytes"},
        texture_id: %Schema{type: :string, description: "The texture id used by Minecraft"},
        value: %Schema{type: :string, description: "The value of the skin data used by Minecraft"},
        signature: %Schema{type: :string, description: "The signature of the skin data used by Minecraft"},
        is_steve: %Schema{type: :boolean, description: "If the skin is a Steve or an Alex"}
      },
      required: [:hash, :texture_id, :value, :singature, :is_steve]
    })
  end

  defmodule Link do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      description: "A link between a Java and a Bedrock account",
      type: :object,
      properties: %{
        bedrock_id: %Schema{type: :integer, format: :int64, description: "xuid of the Bedrock player", example: 2535432196048835},
        java_id: %Schema{type: :string, format: :uuid, description: "UUID of the Java player", example: "d34eb447-6e90-4c78-9281-600df88aef1d"},
        java_name: %Schema{type: :string, description: "Username of the Java player", example: "Tim203"},
        last_name_update: %Schema{type: :integer, format: :int64, description: "Unix millis of the last Java name update check"}
      },
      required: [:bedrock_id, :java_id, :java_name, :last_name_update]
    })
  end

  defmodule LinkList do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      description: "Response schema for a list of links",
      type: :array,
      items: Link
    })
  end

  defmodule RecentConvertedSkinReference do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      description: "The most basic info required to show a Java skin on the site",
      type: :object,
      properties: %{
        id: %Schema{type: :integer, description: "The converted skin id"},
        texture_id: %Schema{type: :string, description: "The texture id used by Minecraft"}
      },
      required: [:id, :texture_id]
    })
  end

  defmodule RecentConvertedSkinList do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      description: "List of most recently converted skins. Ordered by most recently converted",
      type: :object,
      properties: %{
        data: %Schema{
          type: :array,
          items: RecentConvertedSkinReference
        },
        total_pages: %Schema{type: :integer, description: "The amount of pages available"}
      }
    })
  end

  defmodule Statistics do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      description: "All publicly available statistics",
      type: :object,
      properties: %{
        pre_upload_queue: %Schema{
          type: :object,
          properties: %{
            length: %Schema{type: :integer, description: "The amount of skins in the pre-upload queue"}
          }
        },
        upload_queue: %Schema{
          type: :object,
          properties: %{
            estimated_duration: %Schema{type: :number, format: :decimal, description: "Estimated duration to upload 'length' amount of skins"},
            length: %Schema{type: :integer, description: "The amount of skins in the upload queue"}
          }
        }
      }
    })
  end

  defmodule UsernameProfile do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      description: "Username to Floodgate UUID in Mojang Minecraft profile format",
      type: :object,
      properties: %{
        id: %Schema{type: :string, format: :uuid, description: "The Floodgate UUID of the Bedrock player", example: "0000000000000000000901f64f65c7c3"},
        name: %Schema{type: :string, description: "The Floodgate username", example: ".Tim203"}
      },
      required: [:id, :name]
    })
  end

  defmodule XboxGamertagResult do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      description: "Get gamertag from xuid result",
      type: :object,
      properties: %{
        gamertag: %Schema{type: :string, description: "The gamertag", example: "Tim203", required: true}
      }
    })
  end

  defmodule XboxXuidResult do
    require OpenApiSpex

    OpenApiSpex.schema(%{
      description: "Get xuid from gamertag result",
      type: :object,
      properties: %{
        xuid: %Schema{type: :integer, format: :int64, description: "The xuid", example: 2535432196048835, required: true}
      }
    })
  end
end
