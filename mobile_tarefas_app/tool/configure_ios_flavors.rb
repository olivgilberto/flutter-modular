# Cria os flavors do iOS (capítulo 26), com a gem xcodeproj, a mesma que o
# CocoaPods usa para editar projetos do Xcode. Nunca edite o
# project.pbxproj à mão. Pode rodar de novo: só cria o que falta.
#
# Uso, na pasta mobile_tarefas_app:  ruby tool/configure_ios_flavors.rb
require 'xcodeproj'

BASE_ID = 'com.zayitbrazil.mobiletarefas'
BASE_NAME = 'Tarefas'
FLAVORS = {
  'dev' => { suffix: '.dev', name: 'Tarefas Dev' },
  'staging' => { suffix: '.staging', name: 'Tarefas Stg' },
  'prod' => { suffix: '', name: 'Tarefas' },
}.freeze
BASES = { 'Debug' => :debug, 'Profile' => :release, 'Release' => :release }.freeze

IOS = File.expand_path('../ios', __dir__)
project = Xcodeproj::Project.open(File.join(IOS, 'Runner.xcodeproj'))
runner = project.targets.find { |t| t.name == 'Runner' } or abort 'sem o alvo Runner'
tests = project.targets.find { |t| t.name == 'RunnerTests' }
flutter_group = project.main_group['Flutter'] or abort 'sem o grupo Flutter'

def config_named(list, name)
  list.build_configurations.find { |c| c.name == name }
end

# Copia uma configuração base (Debug, Profile, Release) com outro nome, na
# mesma lista: o projeto e cada alvo têm a sua.
def copy_config(project, list, base_name, name)
  existing = config_named(list, name)
  return existing if existing

  base = config_named(list, base_name) or abort "sem a configuração #{base_name}"
  config = project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
  config.name = name
  config.build_settings = Marshal.load(Marshal.dump(base.build_settings))
  config.base_configuration_reference = base.base_configuration_reference
  list.build_configurations << config
  config
end

# As configurações sem flavor, do template, ficam com o identificador de
# produção: são as que o esquema Runner usa.
BASES.each_key do |base|
  settings = config_named(runner.build_configuration_list, base).build_settings
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = BASE_ID
  settings['APP_DISPLAY_NAME'] = BASE_NAME
  if tests
    config_named(tests.build_configuration_list, base)
      .build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "#{BASE_ID}.RunnerTests"
  end
end

FLAVORS.each do |flavor, values|
  BASES.each_key do |base|
    name = "#{base}-#{flavor}"
    copy_config(project, project.build_configuration_list, base, name)

    # O Runner lê o identificador e o nome do xcconfig da configuração. Um
    # valor nas configurações do alvo venceria o do xcconfig, por isso sai.
    xcconfig = File.join(IOS, 'Flutter', "#{name}.xcconfig")
    unless File.exist?(xcconfig)
      File.write(xcconfig, <<~XCCONFIG)
        // Gerado por tool/configure_ios_flavors.rb (capítulo 26).
        #include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.#{name.downcase}.xcconfig"
        #include "Generated.xcconfig"
        PRODUCT_BUNDLE_IDENTIFIER = #{BASE_ID}#{values[:suffix]}
        APP_DISPLAY_NAME = #{values[:name]}
      XCCONFIG
    end
    reference = flutter_group.files.find { |f| f.real_path.to_s == xcconfig } ||
                flutter_group.new_file(xcconfig)
    config = copy_config(project, runner.build_configuration_list, base, name)
    config.base_configuration_reference = reference
    config.build_settings.delete('PRODUCT_BUNDLE_IDENTIFIER')
    config.build_settings.delete('APP_DISPLAY_NAME')

    next unless tests

    # O CocoaPods liga o xcconfig dos testes na próxima instalação.
    config = copy_config(project, tests.build_configuration_list, base, name)
    config.base_configuration_reference = nil
    config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] =
      "#{BASE_ID}#{values[:suffix]}.RunnerTests"
  end
end
project.save

# Um esquema compartilhado por flavor, com o nome do flavor: é o que o
# `flutter run --flavor` procura. Cada ação usa a configuração do flavor.
schemes = File.join(IOS, 'Runner.xcodeproj', 'xcshareddata', 'xcschemes')
template = File.read(File.join(schemes, 'Runner.xcscheme'))
FLAVORS.each_key do |flavor|
  path = File.join(schemes, "#{flavor}.xcscheme")
  next if File.exist?(path)

  File.write(path, template.gsub(/buildConfiguration = "(Debug|Profile|Release)"/) do
    %(buildConfiguration = "#{Regexp.last_match(1)}-#{flavor}")
  end)
end

# O nome na tela vem da variável de cada configuração.
plist_path = File.join(IOS, 'Runner', 'Info.plist')
plist = Xcodeproj::Plist.read_from_path(plist_path)
plist['CFBundleDisplayName'] = '$(APP_DISPLAY_NAME)'
Xcodeproj::Plist.write_to_path(plist, plist_path)

# O CocoaPods precisa saber se cada configuração nova é de debug ou release.
podfile_path = File.join(IOS, 'Podfile')
podfile = File.read(podfile_path)
unless podfile.include?("'Debug-dev'")
  entries = FLAVORS.keys.flat_map do |flavor|
    BASES.map { |base, kind| "  '#{base}-#{flavor}' => :#{kind}," }
  end
  podfile.sub!(/^project 'Runner', \{\n/) { |head| head + entries.join("\n") + "\n" }
  File.write(podfile_path, podfile)
end

puts "Flavors do iOS: #{FLAVORS.keys.join(', ')}"
