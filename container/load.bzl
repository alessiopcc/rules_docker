# Copyright 2017 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Rule for loading an image from 'docker save' tarball or the current
   container_pull tarball format into OCI intermediate layout.

This extracts the tarball amd creates a filegroup of the untarred objects in OCI layout.
"""

def _impl(repository_ctx):
    """Core implementation of container_load."""

    # Add an empty top-level BUILD file.
    repository_ctx.file("BUILD", "")

    repository_ctx.file("image/BUILD", """
package(default_visibility = ["//visibility:public"])
load("@io_bazel_rules_docker//container:import.bzl", "container_import")

container_import(
    name = "image",
    config = "config.json",
    layers = glob(["*.tar.gz"]),
)""")

    loader = repository_ctx.attr._loader_linux
    if repository_ctx.os.name.lower().startswith("mac os"):
        loader = repository_ctx.attr._loader_darwin

    loader_path = repository_ctx.path(loader)
    directory_path = repository_ctx.path("image")
    tarball_path = repository_ctx.path(repository_ctx.attr.file)

    args = []

    if repository_ctx.os.name.lower().startswith("windows"):
        args += ["wsl"]

        wsl_loader = repository_ctx.execute(["wsl", "wslpath", "-a", loader_path])
        if not wsl_loader.return_code:
            loader_path = wsl_loader.stdout.strip()

        wsl_directory = repository_ctx.execute(["wsl", "wslpath", "-a", directory_path])
        if not wsl_directory.return_code:
            directory_path = wsl_directory.stdout.strip()

        wsl_tarball = repository_ctx.execute(["wsl", "wslpath", "-a", tarball_path])
        if not wsl_tarball.return_code:
            tarball_path = wsl_tarball.stdout.strip()

    args += [
        loader_path,
        "-directory",
        directory_path,
        "-tarball",
        tarball_path,
    ]

    result = repository_ctx.execute(args)

    if result.return_code:
        fail("Importing from tarball failed (status %s): %s" % (result.return_code, result.stderr))

container_load = repository_rule(
    attrs = {
        "file": attr.label(
            allow_single_file = True,
            mandatory = True,
        ),
        "_loader_darwin": attr.label(
            executable = True,
            default = Label("@loader_darwin//file:downloaded"),
            cfg = "host",
        ),
        "_loader_linux": attr.label(
            executable = True,
            default = Label("@loader_linux//file:downloaded"),
            cfg = "host",
        ),
    },
    implementation = _impl,
)
