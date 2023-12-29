import json
import os
import shutil

from BuildEnvironment import is_apple_silicon, call_executable, BuildEnvironment


def remove_directory(path):
    if os.path.isdir(path):
        shutil.rmtree(path)

def generate_xcodeproj(build_environment: BuildEnvironment, disable_extensions, disable_provisioning_profiles, include_release, generate_dsym, configuration_path, bazel_startup_arguments, bazel_app_arguments, target_name):
    if '/' in target_name:
        app_target_spec = target_name.split('/')[0] + '/' + target_name.split('/')[1] + ':' + target_name.split('/')[1]
        app_target = target_name
        app_target_clean = app_target.replace('/', '_')
    else:
        app_target_spec = '{target}:{target}'.format(target=target_name)
        app_target = target_name
        app_target_clean = app_target.replace('/', '_')

    bazel_generate_arguments = [build_environment.bazel_path]
    bazel_generate_arguments += bazel_startup_arguments

    bazel_generate_arguments += ['run', '//{}_xcodeproj'.format(app_target_spec)]
    bazel_generate_arguments += ['--override_repository=build_configuration={}'.format(configuration_path)]

    if target_name == 'Telegram':
        if disable_extensions:
            bazel_generate_arguments += ['--//{}:disableExtensions'.format(app_target)]
        if disable_provisioning_profiles:
            bazel_generate_arguments += ['--//{}:disableProvisioningProfiles'.format(app_target)]
        bazel_generate_arguments += ['--//{}:disableStripping'.format(app_target)]

    project_bazel_arguments = []
    for argument in bazel_app_arguments:
        project_bazel_arguments.append(argument)
    project_bazel_arguments += ['--override_repository=build_configuration={}'.format(configuration_path)]

    if target_name == 'Telegram':
        if disable_extensions:
            project_bazel_arguments += ['--//{}:disableExtensions'.format(app_target)]
        if disable_provisioning_profiles:
            project_bazel_arguments += ['--//{}:disableProvisioningProfiles'.format(app_target)]
        project_bazel_arguments += ['--//{}:disableStripping'.format(app_target)]

    project_bazel_arguments += ['--features=-swift.debug_prefix_map']
    
    xcodeproj_bazelrc = os.path.join(build_environment.base_path, 'xcodeproj.bazelrc')
    if os.path.isfile(xcodeproj_bazelrc):
        os.unlink(xcodeproj_bazelrc)
    with open(xcodeproj_bazelrc, 'w') as file:
        for argument in bazel_startup_arguments:
            file.write('startup ' + argument + '\n')
        for argument in project_bazel_arguments:
            file.write('build ' + argument + '\n')

    call_executable(bazel_generate_arguments)

    xcodeproj_path = '{}.xcodeproj'.format(app_target_spec.replace(':', '/'))
    call_executable(['open', xcodeproj_path])


def generate(build_environment: BuildEnvironment, disable_extensions, disable_provisioning_profiles, include_release, generate_dsym, configuration_path, bazel_startup_arguments, bazel_app_arguments, target_name):
    generate_xcodeproj(build_environment, disable_extensions, disable_provisioning_profiles, include_release, generate_dsym, configuration_path, bazel_startup_arguments, bazel_app_arguments, target_name)
