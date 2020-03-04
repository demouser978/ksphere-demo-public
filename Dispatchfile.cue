resource "src-git": {
  type: "git"
  param url: "$(context.git.url)"
  param revision: "$(context.git.commit)"
}

apps:: [ "map", "flickr", "photos" ]

for _, app in apps {
  resource "docker-image-\(app)": {
    type: "image"
    param url: "demouser978/ksphere-demo-public-\(app):$(context.build.name)"
  }
}

resource "gitops-git": {
  type: "git"
  param url: "https://github.com/demouser978/ksphere-demo-gitops-public"
}

task "test-photos": {
  inputs: ["src-git"]

  steps: [
    {
      name: "test"
      image: "python:3"
      command: ["python3", "test.py"]
      workingDir: "/workspace/src-git/photos"
    }
  ]
}

for _, app in apps {
  task "build-\(app)": {
    inputs: ["src-git"]
    outputs: ["docker-image-\(app)"]
    if app == "photos" {
      deps: ["test-photos"]
    }

    steps: [
      {
        name: "build-and-push"
        image: "chhsiao/kaniko-executor"
        args: [
          "--destination=$(outputs.resources.docker-image-\(app).url)",
          "--context=/workspace/src-git/\(app)",
          "--oci-layout-path=/workspace/output/docker-image-\(app)",
          "--dockerfile=/workspace/src-git/\(app)/Dockerfile"
        ],
        env: [
          {
            name: "DOCKER_CONFIG"
            value: "/tekton/home/.docker"
          }
        ]
      }
    ]
  }
}

for _, app in apps {
  task "deploy-\(app)": {
    inputs: ["docker-image-\(app)", "gitops-git"]
    steps: [
      {
        name: "update-gitops-repo"
        image: "mesosphere/update-gitops-repo:v1.0"
        workingDir: "/workspace/gitops-git"
        args: [
          "-git-revision=$(context.git.commit)",
          "-branch=$(context.git.commit)-\(app)",
          "-filepath=\(app)/application.yaml.tmpl",
          "-create-pull-request=true",
          "-substitute=imageName=$(inputs.resources.docker-image-\(app).url)@$(inputs.resources.docker-image-\(app).digest)"
        ]
      }
    ]
  }
}

actions: [
  {
    tasks: ["test-photos"]
    on: {
        push: {
            branches: ["master"]
            paths: ["photos/**"]
        }
    }
  }
] + [
  {
    tasks: ["build-\(app)", "deploy-\(app)"]
    on push: {
      branches: ["master"]
      paths: ["\(app)/**"]
    }
  } for _, app in apps
]
